module OuterJoins
  def outer_joins(*associations)
    pattern = / (?:INNER )?JOIN /i
    scope = all
    associations.each do |association|
      inner_join_sql = scope.unscoped.joins(association).to_sql
      outer_join_sql = inner_join_sql.gsub(pattern, ' LEFT OUTER JOIN ')
      scope = scope.joins(outer_join_sql[/LEFT OUTER JOIN .+/])
    end

    return scope
  end
end

ActiveRecord::Base.extend OuterJoins
