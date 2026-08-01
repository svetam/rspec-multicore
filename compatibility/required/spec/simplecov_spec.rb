# frozen_string_literal: true

require "spec_helper"

RSpec.describe "SimpleCov compatibility" do
  it "finalizes and collates coverage from every worker" do
    Dir.mktmpdir("rspec-multicore-simplecov") do |directory|
      serial = Compatibility.run_rspec(
        "simplecov",
        workers: 0,
        output: File.join(directory, "serial.json"),
        env: { "COVERAGE_ROOT" => File.join(directory, "serial") }
      )
      parallel = Compatibility.run_rspec(
        "simplecov",
        workers: 2,
        output: File.join(directory, "parallel.json"),
        env: { "COVERAGE_ROOT" => directory }
      )

      expect(serial.exit_code).to eq(0), serial.output
      expect(parallel.exit_code).to eq(0), parallel.output
      expect(Compatibility.example_results(File.join(directory, "parallel.json")))
        .to eq(Compatibility.example_results(File.join(directory, "serial.json")))
      resultsets = Dir[File.join(directory, "worker-*", ".resultset.json")]
      expect(resultsets.size).to eq(2)
      expect(resultsets.flat_map { JSON.parse(File.read(_1)).keys })
        .to contain_exactly("rspec-multicore-worker-1", "rspec-multicore-worker-2")

      summary = File.join(directory, "merged.json")
      collate = Compatibility.run_ruby(
        File.join(Compatibility::FIXTURES, "simplecov", "collate.rb"),
        directory,
        summary
      )
      expect(collate.exit_code).to eq(0), collate.output

      coverage = JSON.parse(File.read(summary))
      expect(coverage.keys).to contain_exactly("alpha.rb", "beta.rb")
      expect(coverage.values).to all(be_an(Array).and(be_any))

      html = File.join(directory, "merged", "index.html")
      expect(File).to exist(html)
      expect(File.read(html)).to include("coverage_data.js")
      expect(File.read(File.join(directory, "merged", "coverage_data.js")))
        .to include("alpha.rb", "beta.rb")
    end
  end
end
