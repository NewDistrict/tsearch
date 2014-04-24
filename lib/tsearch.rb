require "tsearch/version"
require 'tsearch/outer_joins'

module TSearch

  TSEARCH_OPERATORS = ['!', '&', '|', '(', ')', '\\']
  OPERATOR_DICTIONARY = {:and => '&', :or => '|', :not => '!'}
  DEFAULT_OPERATOR = :and

  module Scope
    def tsearch_scope(scope_name, fields:, **options)
      joins, attributes = Array(fields).flatten.partition {|field| field.is_a?(Hash)}

      scope scope_name, lambda {|text|
        if text.present?
          scope = all
          condition = []

          # Join on the tables we specified
          joins.each do |hash|
            hash.each do |association, columns|
              scope = scope.outer_joins(association)
              Array.wrap(columns).each do |column|
                condition << "#{reflect_on_association(association).quoted_table_name}.#{connection.quote_column_name column}"
              end
            end
          end

          # Ensure that if just the column name was passed, we quote it and add the table name
          # Allows us to pass references to attributes in other tables, e.g. if a has many through association
          # is already loaded, and we want to reference columns in the join table, but don't want to double join the table accidentally
          # we could instead pass 'join_table.desired_column' as an attribute instead of :join_table => :column
          attributes.each do |attribute|
            condition << (attribute.to_s.include?('.') ? attribute : "#{quoted_table_name}.#{connection.quote_column_name attribute}")
          end

          condition = condition.join(" || ' ' || ")

          # Add the where clause
          scope = scope.where(TSearch.search_condition(condition, text, options))

          # Add a group clause if there are joins since they could cause duplicate rows
          scope = scope.group("#{quoted_table_name}.#{connection.quote_column_name primary_key}") if joins.present?

          # Order by relevance
          if joins.present?
            scope = scope.order(TSearch.sum_rank(condition, text, options)).order(:id)
          else
            scope = scope.order(TSearch.rank(condition, text, options)).order(:id)
          end
        end
      }
    end
  end

  # REGULAR COLUMNS
  # Generate an SQL condition that can be used in a scope
  def self.search_condition(column, text, options = {})
    "#{to_tsvector(column, options)} @@ #{to_tsquery(text, options)}"
  end

  def self.sum_rank(column, text, options = {})
    "SUM(ts_rank_cd(#{to_tsvector(column, options)}, #{to_tsquery(text, options)}, 8)) DESC"
  end

  def self.rank(column, text, options = {})
    "ts_rank_cd(#{to_tsvector(column, options)}, #{to_tsquery(text, options)}, 8) DESC"
  end

  def self.ts_headline(column, text, as = 'headline', options = {})
    "ts_headline(#{column}, #{to_tsquery(text, options)}, E'StartSel=<mark>, StopSel=</mark>') AS #{as}"
  end

  def self.to_tsquery(text, dictionary: 'english', **options)
    "to_tsquery('#{dictionary}', #{to_querytext(text, options)})"
  end

  def self.to_tsvector(column, dictionary: 'english', **options)
    "to_tsvector('#{dictionary}', #{column})"
  end

  # TS VECTOR COLUMNS
  # Generate an SQL condition that can be used in a scope (for use with pregenerated ts_vector columns
  def self.ts_vector_search_condition(column, text, options = {})
    "#{column} @@ #{to_tsquery(text, options)}"
  end

  def self.ts_vector_rank(column, text, options = {})
    "ts_rank_cd(#{column}, #{to_tsquery(text, options)}, 4)"
  end


  # Turn text into a simple tsquery
  # All whitespace is converted to the given operator, (default is AND)
  # Prefix matching is enabled by the ':*'
  def self.to_querytext(text, operator: DEFAULT_OPERATOR, **options)
    ActiveRecord::Base.connection.quote(escape(text).strip.squeeze(' ').gsub(/\s/, lookup_operator_symbol(operator)) + ':*')
  end

  private

  # Escapes operators used in tsearches
  def self.escape(query_string)
    query_string = query_string.dup
    query_string.gsub!(/([#{Regexp.escape(TSEARCH_OPERATORS.join)}])/, "\\\\" + '\1')
    # Escape semicolons (eg. Sto:lo)
    query_string.gsub!(/:/, '\\:')
    # Remove any number of single quotes from the beginning of all words because the tsearch doesn't like them.
    query_string.gsub!(/(\A|\s)'+/, '\1')

    return query_string
  end

  def self.lookup_operator_symbol(operator_string)
    operator = operator_string.nil? ? OPERATOR_DICTIONARY[DEFAULT_OPERATOR] : OPERATOR_DICTIONARY[operator_string.to_s.downcase.to_sym]
    raise 'TSearch operator not found' if operator.nil?
    return operator
  end
end

ActiveRecord::Base.extend TSearch::Scope
