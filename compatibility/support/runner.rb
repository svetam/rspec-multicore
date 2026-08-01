# frozen_string_literal: true

require "json"
require "open3"

module Compatibility
  Result = Data.define(:output, :exit_code)

  ROOT = File.expand_path("../..", __dir__)
  FIXTURES = File.join(ROOT, "compatibility", "fixtures")
  EMPTY_OPTIONS = File.join(FIXTURES, ".rspec")
  SEED = "31415"

  module_function

  def run_rspec(fixture, workers:, output: nil, formatter: "json", env: {}, extra_args: [])
    fixture_path = File.join(FIXTURES, fixture)
    command = [
      "bundle", "exec", "rspec",
      "--options", EMPTY_OPTIONS,
      "--require", File.join(fixture_path, "spec_helper.rb"),
      "--order", "rand:#{SEED}",
      "--seed", SEED,
      "--format", formatter,
      *(output ? ["--out", output] : []),
      *extra_args,
      *Dir[File.join(fixture_path, "*_spec.rb")]
    ]
    child_env = {
      "RSPEC_MULTICORE" => workers.to_s,
      "SPEC" => nil,
      "SPEC_OPTS" => nil,
      **env
    }
    stdout, stderr, status = Open3.capture3(child_env, *command, chdir: ROOT)
    Result.new("#{stdout}#{stderr}", status.exitstatus)
  end

  def run_ruby(script, *args, env: {})
    command = ["bundle", "exec", "ruby", script, *args]
    stdout, stderr, status = Open3.capture3(env, *command, chdir: ROOT)
    Result.new("#{stdout}#{stderr}", status.exitstatus)
  end

  def example_results(path)
    JSON.parse(File.read(path)).fetch("examples").map do |example|
      example.values_at("id", "full_description", "status")
    end
  end

  def evidence(path)
    return [] unless File.exist?(path)

    File.readlines(path, chomp: true).reject(&:empty?).map { JSON.parse(_1) }
  end
end
