# frozen_string_literal: true

require "simplecov"

coverage_root = ENV.fetch("COVERAGE_ROOT")
SimpleCov.start do
  root File.expand_path(__dir__)
  coverage_dir File.join(coverage_root, "parent")
end
SimpleCov.at_exit {}

require "rspec/multicore"

RSpec::Multicore.on_worker_fork do |slot|
  SimpleCov.command_name("rspec-multicore-worker-#{slot}")
  SimpleCov.coverage_dir(File.join(coverage_root, "worker-#{slot}"))
end

RSpec::Multicore.on_worker_shutdown do
  SimpleCov.result.format!
end
