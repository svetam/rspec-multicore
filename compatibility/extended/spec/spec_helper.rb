# frozen_string_literal: true

ENV["RSPEC_MULTICORE"] = "0"

require "fileutils"
require "rspec"
require "tmpdir"
require_relative "../../support/runner"

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with(:rspec) { _1.syntax = :expect }
end
