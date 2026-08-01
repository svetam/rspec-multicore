# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Bullet compatibility" do
  it "preserves subscriptions and detects query problems in each worker" do
    Dir.mktmpdir("rspec-multicore-bullet") do |directory|
      serial = run_bullet(directory, "serial", 0)
      parallel = run_bullet(directory, "parallel", 2)

      expect(serial.exit_code).to eq(0), serial.output
      expect(parallel.exit_code).to eq(0), parallel.output
      expect(Compatibility.example_results(File.join(directory, "parallel.json")))
        .to eq(Compatibility.example_results(File.join(directory, "serial.json")))
      expect(Compatibility.evidence(File.join(directory, "parallel.jsonl")).map { _1.fetch("slot") })
        .to contain_exactly("1", "2")
    end
  end

  def run_bullet(directory, name, workers)
    Compatibility.run_rspec(
      "bullet", workers:, output: File.join(directory, "#{name}.json"),
                env: {
                  "DATABASE_PATH" => File.join(directory, "#{name}.sqlite3"),
                  "EVIDENCE_PATH" => File.join(directory, "#{name}.jsonl")
                }
    )
  end
end
