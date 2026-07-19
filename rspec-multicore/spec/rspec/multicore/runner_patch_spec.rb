# frozen_string_literal: true

RSpec.describe RSpec::Multicore::RunnerPatch do
  let(:configuration) { RSpec::Core::Configuration.new }
  let(:runner) do
    Class.new do
      include RSpec::Multicore::RunnerPatch

      def initialize(configuration) = @configuration = configuration
    end.new(configuration)
  end

  around do |example|
    original = ENV.fetch("RSPEC_MULTICORE", nil)
    ENV["RSPEC_MULTICORE"] = "2"
    example.run
  ensure
    original ? ENV["RSPEC_MULTICORE"] = original : ENV.delete("RSPEC_MULTICORE")
  end

  it "is the only module prepended ahead of RSpec::Core::Runner" do
    expect(RSpec::Core::Runner.ancestors.first).to eq(described_class)
  end

  it "parallelizes multiple groups" do
    expect(runner.send(:parallelize?, [Object.new, Object.new])).to be true
  end

  it "uses serial execution for fail-fast" do
    configuration.fail_fast = true

    expect(runner.send(:parallelize?, [Object.new, Object.new])).to be false
  end

  it "uses serial execution when disabled" do
    ENV["RSPEC_MULTICORE"] = "0"

    expect(runner.send(:parallelize?, [Object.new, Object.new])).to be false
  end
end
