# frozen_string_literal: true

require "spec_helper"

RSpec.describe "rspec_junit_formatter compatibility" do
  it "produces one complete report from parent-replayed events" do
    Dir.mktmpdir("rspec-multicore-junit") do |directory|
      serial_path = File.join(directory, "serial.xml")
      parallel_path = File.join(directory, "parallel.xml")
      serial = run_junit(0, serial_path)
      parallel = run_junit(2, parallel_path)

      expect(serial.exit_code).to eq(1), serial.output
      expect(parallel.exit_code).to eq(serial.exit_code), parallel.output
      expect(junit_summary(parallel_path)).to eq(junit_summary(serial_path))
    end
  end

  def run_junit(workers, output)
    Compatibility.run_rspec(
      "junit",
      workers:,
      output:,
      formatter: "RspecJunitFormatter",
      extra_args: ["--require", "rspec_junit_formatter"]
    )
  end

  def junit_summary(path)
    suite = REXML::Document.new(File.read(path)).elements["testsuite"]
    expect(suite).not_to be_nil
    cases = suite.get_elements("testcase").map do |testcase|
      duration = Float(testcase.attributes["time"].to_s)
      expect(duration).to be >= 0
      [testcase.attributes["classname"], testcase.attributes["name"], outcome(testcase)]
    end
    expect(cases.uniq.size).to eq(cases.size)
    attributes = %w[tests failures skipped].to_h { [_1, Integer(suite.attributes[_1].to_s)] }
    { attributes:, cases: }
  end

  def outcome(testcase)
    return "failure" if testcase.elements["failure"]
    return "skipped" if testcase.elements["skipped"]

    "passed"
  end
end
