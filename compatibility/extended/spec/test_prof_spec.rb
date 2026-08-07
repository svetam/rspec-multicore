# frozen_string_literal: true

require "spec_helper"

RSpec.describe "TestProf compatibility" do
  it "explicitly finalizes a distinct profiler artifact from every worker" do
    Dir.mktmpdir("rspec-multicore-test-prof") do |directory|
      serial = Compatibility.run_rspec(
        "test_prof", workers: 0, output: File.join(directory, "serial.json"),
                     env: { "PROFILE_DIRECTORY" => directory }
      )
      parallel = Compatibility.run_rspec(
        "test_prof", workers: 2, output: File.join(directory, "parallel.json"),
                     env: { "PROFILE_DIRECTORY" => directory }
      )

      expect(serial.exit_code).to eq(0), serial.output
      expect(parallel.exit_code).to eq(0), parallel.output
      expect(Compatibility.example_results(File.join(directory, "parallel.json")))
        .to eq(Compatibility.example_results(File.join(directory, "serial.json")))
      profiles = Dir[File.join(directory, "worker-*.json")].map { JSON.parse(File.read(_1)) }
      expect(profiles.size).to eq(2)
      expect(profiles.map { _1.fetch("total_count") }).to all(eq(1))
      expect(profiles.flat_map { _1.fetch("factories") }).to contain_exactly("first", "second")
    end
  end
end
