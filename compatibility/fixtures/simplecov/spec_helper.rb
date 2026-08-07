# frozen_string_literal: true

require "json"
require "simplecov"

coverage_root = ENV.fetch("COVERAGE_ROOT")
summary_formatter = Class.new do
  define_method(:format) do |result|
    coverage = result.files.select { _1.filename.include?("/lib/") }.to_h do |file|
      [File.basename(file.filename), file.covered_lines.map(&:line_number)]
    end
    File.write(ENV.fetch("COVERAGE_SUMMARY"), JSON.generate(coverage))
  end
end

SimpleCov.start do
  root File.expand_path(__dir__)
  coverage_dir File.join(coverage_root, "merged")
  formatter SimpleCov::Formatter::MultiFormatter.new(
    [summary_formatter, SimpleCov::Formatter::HTMLFormatter]
  )
end

require_relative "lib/preloaded"
CoveragePreloaded.call
require "rspec/multicore"

RSpec::Multicore.on_worker_fork do |slot|
  SimpleCov.command_name("rspec-multicore-worker-#{slot}")
  SimpleCov.coverage_dir(File.join(coverage_root, "worker-#{slot}"))
end

RSpec::Multicore.on_worker_shutdown do
  SimpleCov.result
end

RSpec.configure do |config|
  config.after(:suite) do
    resultsets = Dir[File.join(coverage_root, "worker-*", ".resultset.json")]
    next if resultsets.empty?

    SimpleCov.command_name("rspec-multicore-parent")
    SimpleCov.coverage_dir(File.join(coverage_root, "parent"))
    SimpleCov.result
    resultsets << File.join(coverage_root, "parent", ".resultset.json")

    SimpleCov.collate(resultsets) do
      root File.expand_path(__dir__)
      coverage_dir File.join(coverage_root, "merged")
      formatter SimpleCov::Formatter::MultiFormatter.new(
        [summary_formatter, SimpleCov::Formatter::HTMLFormatter]
      )
    end
    SimpleCov.at_exit { nil }
  end
end
