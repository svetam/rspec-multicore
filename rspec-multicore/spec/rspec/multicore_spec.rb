# frozen_string_literal: true

RSpec.describe RSpec::Multicore do
  it "has a version number" do
    expect(RSpec::Multicore::VERSION).not_to be_nil
    expect(RSpec::Multicore::VERSION).to match(/\d+\.\d+\.\d+/)
  end

  describe ".on_worker_fork" do
    after do
      RSpec::Multicore::Hooks.clear!
    end

    it "delegates to Hooks.on_worker_fork" do
      called = false

      described_class.on_worker_fork { called = true }
      RSpec::Multicore::Hooks.run_fork(nil)

      expect(called).to be true
    end

    it "allows multiple hooks to be registered" do
      calls = []

      described_class.on_worker_fork { calls << 1 }
      described_class.on_worker_fork { calls << 2 }
      RSpec::Multicore::Hooks.run_fork(nil)

      expect(calls).to eq([1, 2])
    end
  end
end
