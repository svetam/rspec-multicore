# frozen_string_literal: true

require "rspec/retry"
require "rspec/multicore"
require_relative "../support"

RSpec.configure do |config|
  config.verbose_retry = false
  config.default_retry_count = 2
end
