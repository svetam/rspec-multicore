# frozen_string_literal: true

require_relative "lib/rspec/multicore/version"

Gem::Specification.new do |spec|
  spec.name = "rspec-multicore"
  spec.version = RSpec::Multicore::VERSION
  spec.authors = ["Sveta Markovic"]
  spec.email = ["svetam.sd@pm.me"]

  spec.summary = "Multi-process parallelization for RSpec"
  spec.description = "Single-boot, multi-process execution for RSpec on POSIX systems. " \
                     "The parent loads RSpec once, then runs top-level groups in persistent forked workers."
  spec.homepage = "https://github.com/svetam/rspec-multicore"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/svetam/rspec-multicore/tree/master/rspec-multicore"
  spec.metadata["changelog_uri"] = "https://github.com/svetam/rspec-multicore/blob/master/rspec-multicore/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) { Dir["lib/**/*.rb"] } + %w[README.md CHANGELOG.md LICENSE.txt]
  spec.require_paths = ["lib"]

  spec.add_dependency "rspec-core", "~> 3.13"
end
