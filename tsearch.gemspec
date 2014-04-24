# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tsearch/version'

Gem::Specification.new do |spec|
  spec.name          = "tsearch"
  spec.version       = TSearch::VERSION
  spec.authors       = ["Nicholas Jakobsen"]
  spec.email         = ["nicholas.jakobsen@gmail.com"]
  spec.summary       = %q{Quickly add Postgres TSearch capability to your models}
  # spec.description   = %q{TODO: Write a longer description. Optional.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "pg"
  spec.add_dependency "activerecord", "~> 4.0"
  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
end
