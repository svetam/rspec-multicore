# frozen_string_literal: true

require "tmpdir"

RSpec.describe RSpec::Multicore::Pool do
  class FakeGroup
    attr_reader :id

    def initialize(id, result: true, &work)
      @id = id
      @result = result
      @work = work
    end

    def descendants = [self]
    def examples = []

    def run(_reporter)
      @work&.call
      @result
    end
  end

  let(:configuration) { RSpec::Core::Configuration.new }
  let(:reporter) { instance_double(RSpec::Core::Reporter, notify_non_example_exception: nil) }

  before { RSpec::Multicore::Hooks.clear! }
  after { RSpec::Multicore::Hooks.clear! }

  it "returns ordered results from persistent workers" do
    groups = [FakeGroup.new("one"), FakeGroup.new("two", result: false), FakeGroup.new("three")]
    pool = described_class.new(reporter:, configuration:, workers: 2)

    expect(pool.run(groups)).to eq([true, false, true])
  end

  it "executes every group exactly once" do
    Dir.mktmpdir("multicore-pool") do |directory|
      groups = 6.times.map do |index|
        FakeGroup.new(index.to_s) do
          File.open(File.join(directory, index.to_s), "a") { _1.puts(Process.pid) }
        end
      end

      described_class.new(reporter:, configuration:, workers: 3).run(groups)

      expect(Dir.children(directory).sort).to eq(%w[0 1 2 3 4 5])
      expect(Dir.children(directory).map { File.readlines(File.join(directory, _1)).size }).to all(eq(1))
    end
  end

  it "attempts shutdown hooks in reverse order and reports their failures" do
    Dir.mktmpdir("multicore-hooks") do |directory|
      calls = File.join(directory, "calls")
      RSpec::Multicore.on_worker_shutdown { File.open(calls, "a") { _1.puts("first") } }
      RSpec::Multicore.on_worker_shutdown do
        File.open(calls, "a") { _1.puts("second") }
        raise "shutdown failed"
      end

      result = described_class.new(reporter:, configuration:, workers: 1).run([FakeGroup.new("one")])

      expect(result).to eq([true])
      expect(File.readlines(calls, chomp: true)).to eq(%w[second first])
      expect(reporter).to have_received(:notify_non_example_exception).with(
        an_object_having_attributes(message: "shutdown failed"), anything
      )
    end
  end

  it "skips inherited at_exit callbacks and runs explicit shutdown hooks" do
    Dir.mktmpdir("multicore-exit") do |directory|
      inherited = File.join(directory, "at_exit")
      explicit = File.join(directory, "shutdown")
      RSpec::Multicore.on_worker_fork { at_exit { File.write(inherited, "called") } }
      RSpec::Multicore.on_worker_shutdown { File.write(explicit, "called") }

      described_class.new(reporter:, configuration:, workers: 1).run([FakeGroup.new("one")])

      expect(File).not_to exist(inherited)
      expect(File.read(explicit)).to eq("called")
    end
  end

  it "reports work failures and worker disconnects" do
    failure = FakeGroup.new("failure") { raise "work failed" }
    disconnect = FakeGroup.new("disconnect") { Process.exit!(9) }

    expect(described_class.new(reporter:, configuration:, workers: 1).run([failure])).to eq([false])
    expect(described_class.new(reporter:, configuration:, workers: 1).run([disconnect])).to eq([false])
    expect(reporter).to have_received(:notify_non_example_exception).at_least(:twice)
  end

  it "reports startup failures without leaving workers" do
    pool = described_class.new(reporter:, configuration:, workers: 1)
    allow(Process).to receive(:fork).and_raise(SystemCallError, "fork failed")

    expect(pool.run([FakeGroup.new("one")])).to eq([false])
    expect(pool.workers).to be_empty
    expect(reporter).to have_received(:notify_non_example_exception)
  end

  it "returns immediately for no groups" do
    pool = described_class.new(reporter:, configuration:, workers: 2)

    expect(pool.run([])).to eq([])
    expect(pool.workers).to be_empty
  end

  it "stops queued work after an interrupt" do
    pool = described_class.new(reporter:, configuration:, workers: 2)
    channel = instance_double(RSpec::Multicore::Channel, write: nil)
    worker = described_class::Worker.new(pid: 123, slot: 1, channel:)
    groups = [FakeGroup.new("one"), FakeGroup.new("two"), FakeGroup.new("three")]

    pool.send(:prepare, groups)
    interrupt_handler = pool.instance_variable_get(:@interrupt_handler)
    allow(interrupt_handler).to receive(:interrupted?).and_return(true)
    pool.send(:assign_group, worker)

    expect(channel).to have_received(:write).with([:no_more_groups])
    expect(pool.instance_variable_get(:@results)).to eq([false, false, false])
    expect(reporter).not_to have_received(:notify_non_example_exception)
  end
end
