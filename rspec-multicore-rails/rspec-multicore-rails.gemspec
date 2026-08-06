# frozen_string_literal: true

require_relative "lib/rspec/multicore/rails/version"

Gem::Specification.new do |spec|
  spec.name = "rspec-multicore-rails"
  spec.version = RSpec::Multicore::Rails::VERSION
  spec.authors = ["Sveta Markovic"]
  spec.email = ["svetam.sd@pm.me"]

  spec.summary = "ActiveRecord isolation for rspec-multicore Rails workers"
  spec.description = "Rails adapter for rspec-multicore that assigns each worker an isolated ActiveRecord " \
                     "test database through the standard Rails database-task lifecycle."
  spec.homepage = "https://github.com/svetam/rspec-multicore"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/svetam/rspec-multicore/tree/master/rspec-multicore-rails"
  spec.metadata["changelog_uri"] = "https://github.com/svetam/rspec-multicore/blob/master/rspec-multicore-rails/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) { Dir["lib/**/*.{rake,rb}"] } + %w[README.md CHANGELOG.md LICENSE.txt]
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 7.1", "< 9"
  spec.add_dependency "railties", ">= 7.1", "< 9"
  spec.add_dependency "rspec-multicore", "= #{RSpec::Multicore::Rails::VERSION}"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rubocop", "~> 1.21"
  spec.add_development_dependency "sqlite3", ">= 2.0"
end
