# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Sidekiq compatibility" do
  it "reconnects each worker to an isolated Redis database and closes its pool" do
    Dir.mktmpdir("rspec-multicore-sidekiq") do |directory|
      serial = run_sidekiq(directory, "serial", 0)
      parallel = run_sidekiq(directory, "parallel", 2)

      expect(serial.exit_code).to eq(0), serial.output
      expect(parallel.exit_code).to eq(0), parallel.output
      expect(Compatibility.example_results(File.join(directory, "parallel.json")))
        .to eq(Compatibility.example_results(File.join(directory, "serial.json")))
      evidence = Compatibility.evidence(File.join(directory, "parallel.jsonl"))
      expect(evidence.map { _1.fetch("slot") }).to contain_exactly("1", "2")
      expect(evidence.map { _1.fetch("database") }.uniq.size).to eq(2)
    end
  end

  def run_sidekiq(directory, name, workers)
    Compatibility.run_rspec(
      "sidekiq", workers:, output: File.join(directory, "#{name}.json"),
                 env: {
                   "EVIDENCE_PATH" => File.join(directory, "#{name}.jsonl"),
                   "REDIS_URL" => ENV.fetch("REDIS_URL")
                 }
    )
  end
end
