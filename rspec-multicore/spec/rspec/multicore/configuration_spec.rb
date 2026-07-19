# frozen_string_literal: true

RSpec.describe RSpec::Multicore::Configuration do
  subject(:configuration) { described_class.new }

  around do |example|
    original = ENV.fetch("RSPEC_MULTICORE", nil)
    ENV.delete("RSPEC_MULTICORE")
    example.run
  ensure
    original ? ENV["RSPEC_MULTICORE"] = original : ENV.delete("RSPEC_MULTICORE")
  end

  it "uses the configured worker count" do
    configuration.workers = 3

    expect(configuration.workers).to eq(3)
  end

  it "lets a numeric environment value override configuration" do
    configuration.workers = 3
    ENV["RSPEC_MULTICORE"] = "5"

    expect(configuration.workers).to eq(5)
  end

  it "disables multicore with supported false values" do
    %w[0 false off].each do |value|
      ENV["RSPEC_MULTICORE"] = value
      expect(configuration.workers).to eq(0)
    end
  end

  it "rejects invalid values" do
    ENV["RSPEC_MULTICORE"] = "sometimes"

    expect { configuration.workers }.to raise_error(ArgumentError, /RSPEC_MULTICORE/)
  end

  it "rejects invalid configured worker counts" do
    expect { configuration.workers = 0 }.to raise_error(ArgumentError, /positive integer/)
  end
end

RSpec.describe RSpec::Multicore::Hooks do
  before { described_class.clear! }
  after { described_class.clear! }

  it "runs fork hooks in registration order" do
    calls = []
    described_class.on_fork { |slot| calls << [:first, slot] }
    described_class.on_fork { |slot| calls << [:second, slot] }

    described_class.run_fork(2)

    expect(calls).to eq([[:first, 2], [:second, 2]])
  end

  it "runs every shutdown hook in reverse order and collects errors" do
    calls = []
    described_class.on_shutdown { calls << :first }
    described_class.on_shutdown do
      calls << :second
      raise "failed"
    end

    errors = described_class.run_shutdown(1)

    expect(calls).to eq(%i[second first])
    expect(errors.map(&:message)).to eq(["failed"])
  end
end
