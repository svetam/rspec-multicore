# frozen_string_literal: true

require "byebug"
require "rspec/multicore"

# Disable multicore for unit tests to avoid recursive parallelization
ENV["RSPEC_MULTICORE"] = "0"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
