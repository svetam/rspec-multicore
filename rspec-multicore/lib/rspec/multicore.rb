# frozen_string_literal: true

require "rspec/core/runner"

module RSpec
  module Multicore
    class Error < StandardError; end
    class UnsupportedReporterEvent < Error; end
  end
end

require_relative "multicore/version"
require_relative "multicore/configuration"
require_relative "multicore/channel"
require_relative "multicore/reporter_bridge"
require_relative "multicore/pool"
require_relative "multicore/runner_patch"
