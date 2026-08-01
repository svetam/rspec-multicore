# frozen_string_literal: true

require "spec_helper"
require "sqlite3"

RSpec.describe "common Rails data-test gems" do
  it "keeps FactoryBot and Database Cleaner work isolated by worker database" do
    Dir.mktmpdir("rspec-multicore-rails-stack") do |directory|
      serial = run_stack(directory, "serial", 0)
      parallel = run_stack(directory, "parallel", 2)

      expect(serial.exit_code).to eq(0), serial.output
      expect(parallel.exit_code).to eq(0), parallel.output
      expect(Compatibility.example_results(File.join(directory, "parallel-rspec.json")))
        .to eq(Compatibility.example_results(File.join(directory, "serial-rspec.json")))

      parallel_evidence = Compatibility.evidence(File.join(directory, "parallel.jsonl"))
      expect(parallel_evidence.map { _1.fetch("slot") }).to contain_exactly("1", "2")
      expect(parallel_evidence.map { _1.fetch("database") }.uniq.size).to eq(2)
      expect(database_counts(directory, "parallel")).to all(eq(0))
    end
  end

  def run_stack(directory, name, workers)
    Compatibility.run_rspec(
      "rails_stack",
      workers:,
      output: File.join(directory, "#{name}-rspec.json"),
      env: {
        "DATABASE_PATH" => File.join(directory, "#{name}.sqlite3"),
        "EVIDENCE_PATH" => File.join(directory, "#{name}.jsonl")
      }
    )
  end

  def database_counts(directory, name)
    Dir[File.join(directory, "#{name}*.sqlite3")].map do |path|
      SQLite3::Database.new(path).get_first_value("SELECT COUNT(*) FROM widgets")
    end
  end
end
