# frozen_string_literal: true

# Helper for running fixtures WITHOUT disabling multicore
# This is used by integration tests to properly test parallel execution
require "rspec/multicore"
