# frozen_string_literal: true

require "spec_helper"

RSpec.describe "WebMock and VCR compatibility" do
  it "keeps HTTP state process-local and never mutates the cassette" do
    cassette = File.join(Compatibility::FIXTURES, "http", "cassettes", "response.yml")
    checksum = Digest::SHA256.file(cassette).hexdigest

    Dir.mktmpdir("rspec-multicore-http") do |directory|
      serial = run_http(directory, "serial", 0)
      parallel = run_http(directory, "parallel", 2)

      expect(serial.exit_code).to eq(1), serial.output
      expect(parallel.exit_code).to eq(serial.exit_code), parallel.output
      results = Compatibility.example_results(File.join(directory, "parallel.json"))
      expect(results).to eq(Compatibility.example_results(File.join(directory, "serial.json")))
      expect(results.map(&:last)).to contain_exactly("passed", "passed", "failed")
    end

    expect(Digest::SHA256.file(cassette).hexdigest).to eq(checksum)
  end

  def run_http(directory, name, workers)
    Compatibility.run_rspec(
      "http",
      workers:,
      output: File.join(directory, "#{name}.json"),
      env: { "HTTP_FIXTURE_ROOT" => File.join(Compatibility::FIXTURES, "http") }
    )
  end
end
