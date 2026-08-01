# frozen_string_literal: true

require "json"
require "simplecov"

coverage_root, summary_path = ARGV

summary_formatter = Class.new do
  define_method(:format) do |result|
    coverage = result.files.select { _1.filename.include?("/lib/") }.to_h do |file|
      [File.basename(file.filename), file.covered_lines.map(&:line_number)]
    end
    File.write(summary_path, JSON.generate(coverage))
  end
end

SimpleCov.collate(Dir[File.join(coverage_root, "worker-*", ".resultset.json")]) do
  root File.expand_path(__dir__)
  coverage_dir File.join(coverage_root, "merged")
  formatter SimpleCov::Formatter::MultiFormatter.new(
    [summary_formatter, SimpleCov::Formatter::HTMLFormatter]
  )
end
