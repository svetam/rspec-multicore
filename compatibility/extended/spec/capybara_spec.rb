# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Capybara compatibility" do
  it "preserves rack-test session isolation and serial semantics" do
    Dir.mktmpdir("rspec-multicore-capybara") do |directory|
      serial = run_capybara(directory, "serial", 0)
      parallel = run_capybara(directory, "parallel", 2)

      expect(serial.exit_code).to eq(0), serial.output
      expect(parallel.exit_code).to eq(0), parallel.output
      expect(Compatibility.example_results(File.join(directory, "parallel.json")))
        .to eq(Compatibility.example_results(File.join(directory, "serial.json")))
      expect(Compatibility.evidence(File.join(directory, "parallel.jsonl")).map { _1.fetch("slot") })
        .to contain_exactly("1", "2")
    end
  end

  def run_capybara(directory, name, workers)
    Compatibility.run_rspec(
      "capybara", workers:, output: File.join(directory, "#{name}.json"),
                  env: { "EVIDENCE_PATH" => File.join(directory, "#{name}.jsonl") }
    )
  end
end
