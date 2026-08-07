# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Fuubar compatibility" do
  it "receives ordered parent reporter notifications" do
    Dir.mktmpdir("rspec-multicore-fuubar") do |directory|
      serial = run_fuubar(directory, "serial", 0)
      parallel = run_fuubar(directory, "parallel", 2)

      expect(serial.exit_code).to eq(0), serial.output
      expect(parallel.exit_code).to eq(0), parallel.output
      expect(File.read(File.join(directory, "serial.txt"))).to include("2 examples, 0 failures")
      expect(File.read(File.join(directory, "parallel.txt"))).to include("2 examples, 0 failures")
      expect(Compatibility.example_results(File.join(directory, "parallel.json")))
        .to eq(Compatibility.example_results(File.join(directory, "serial.json")))
      expect(Compatibility.evidence(File.join(directory, "parallel.jsonl")).map { _1.fetch("slot") })
        .to contain_exactly("1", "2")
    end
  end

  def run_fuubar(directory, name, workers)
    Compatibility.run_rspec(
      "fuubar", workers:, formatter: "Fuubar", output: File.join(directory, "#{name}.txt"),
                env: { "EVIDENCE_PATH" => File.join(directory, "#{name}.jsonl") },
                extra_args: ["--format", "json", "--out", File.join(directory, "#{name}.json")]
    )
  end
end
