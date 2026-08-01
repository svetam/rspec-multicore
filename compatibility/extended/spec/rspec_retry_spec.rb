# frozen_string_literal: true

require "spec_helper"

RSpec.describe "rspec-retry compatibility" do
  it "reports only the final result for a retried example" do
    Dir.mktmpdir("rspec-multicore-rspec-retry") do |directory|
      serial = run_retry(directory, "serial", 0)
      parallel = run_retry(directory, "parallel", 2)

      expect(serial.exit_code).to eq(0), serial.output
      expect(parallel.exit_code).to eq(0), parallel.output
      examples = Compatibility.example_results(File.join(directory, "parallel.json"))
      expect(examples).to eq(Compatibility.example_results(File.join(directory, "serial.json")))
      expect(examples.size).to eq(2)
      expect(examples.map(&:first).uniq.size).to eq(2)
      expect(examples.map(&:last)).to all(eq("passed"))
      expect(Compatibility.evidence(File.join(directory, "parallel.jsonl")))
        .to contain_exactly("attempt" => 2)
    end
  end

  def run_retry(directory, name, workers)
    Compatibility.run_rspec(
      "rspec_retry", workers:, output: File.join(directory, "#{name}.json"),
                     env: { "EVIDENCE_PATH" => File.join(directory, "#{name}.jsonl") }
    )
  end
end
