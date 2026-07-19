# frozen_string_literal: true

RSpec.describe RSpec::Multicore::ReporterBridge do
  let(:result) { RSpec::Core::Example::ExecutionResult.new }
  let(:example) do
    double("example", id: "example-id", metadata: { description: "example" },
                      description: "example", execution_result: result)
  end
  let(:group) { double("group", id: "group-id") }
  let(:registry) { instance_double(RSpec::Multicore::ObjectRegistry, group:, example:) }
  let(:reporter) { double("reporter") }
  subject(:bridge) { described_class.new(registry, reporter) }

  it "replays group events with the parent group" do
    expect(registry).to receive(:group).with("group-id").and_return(group)
    expect(reporter).to receive(:example_group_started).with(group)

    bridge.replay(:example_group_started, "group-id")
  end

  it "updates and replays the parent example" do
    payload = {
      id: "example-id",
      description: "runtime description",
      result: {
        status: :passed, started_at: { time: 1.0 }, finished_at: { time: 2.0 }, run_time: 1.0,
        pending_message: nil, pending_fixed: false, exception: nil, pending_exception: nil
      }
    }
    expect(registry).to receive(:example).with("example-id").and_return(example)
    expect(reporter).to receive(:example_passed).with(example)

    bridge.replay(:example_passed, payload)

    expect(result.status).to eq(:passed)
    expect(result.run_time).to eq(1.0)
    expect(example.metadata[:description]).to eq("runtime description")
  end

  it "completes a generated full description only once" do
    generated = double(
      "generated example",
      id: "example-id",
      metadata: { description: "", full_description: "group " },
      execution_result: result
    )
    payload = {
      id: "example-id", description: "is expected to work",
      result: {
        status: :passed, started_at: nil, finished_at: nil, run_time: 0.1,
        pending_message: nil, pending_fixed: false, exception: nil, pending_exception: nil
      }
    }
    allow(registry).to receive(:example).with("example-id").and_return(generated)
    allow(reporter).to receive(:example_passed)

    2.times { bridge.replay(:example_passed, payload) }

    expect(generated.metadata[:description]).to eq("is expected to work")
    expect(generated.metadata[:full_description]).to eq("group is expected to work")
  end

  it "rejects unsupported events" do
    expect { bridge.replay(:custom_event, {}) }
      .to raise_error(RSpec::Multicore::UnsupportedReporterEvent, /custom_event/)
  end
end

RSpec.describe RSpec::Multicore::ObjectRegistry do
  it "indexes top-level groups, descendants, and their examples by ID" do
    top_example = double("top example", id: "top example")
    nested_example = double("nested example", id: "nested example")
    nested = double("nested", id: "nested", examples: [nested_example])
    top = double("top", id: "top", examples: [top_example])
    allow(top).to receive(:descendants).and_return([top, nested])

    registry = described_class.new([top])

    expect(registry.group("top")).to equal(top)
    expect(registry.group("nested")).to equal(nested)
    expect(registry.example("top example")).to equal(top_example)
    expect(registry.example("nested example")).to equal(nested_example)
  end
end

RSpec.describe RSpec::Multicore::ReporterProxy do
  let(:writer) { double("writer", emit: nil) }
  subject(:proxy) { described_class.new(writer) }

  it "writes bounded IDs and snapshots for standard events" do
    group = double("group", id: "group-id")
    result = RSpec::Core::Example::ExecutionResult.new
    example = double("example", id: "example-id", metadata: { description: "works" }, execution_result: result)

    proxy.example_group_started(group)
    proxy.example_passed(example)

    expect(writer).to have_received(:emit).with(:example_group_started, "group-id")
    expect(writer).to have_received(:emit).with(:example_passed, hash_including(id: "example-id"))
  end

  it "rejects unsupported reporter calls explicitly" do
    expect { proxy.custom_notification(Object.new) }
      .to raise_error(RSpec::Multicore::UnsupportedReporterEvent, /custom_notification/)
  end
end

RSpec.describe RSpec::Multicore::Snapshot do
  it "restores ordinary failures with their class, message, and backtrace" do
    failure = ArgumentError.new("bad argument")
    failure.set_backtrace(["worker.rb:1"])

    restored = described_class.restore_failure(described_class.failure(failure))

    expect(restored).to be_a(ArgumentError)
    expect(restored.message).to eq("bad argument")
    expect(restored.backtrace).to eq(["worker.rb:1"])
  end

  it "restores failures with unusual constructors through RemoteFailure" do
    exception_class = Class.new(StandardError) do
      def initialize = super("fixed")
    end
    stub_const("UnusualFailure", exception_class)
    data = { class: "UnusualFailure", message: "worker message", backtrace: ["line"], cause: nil, children: [] }

    restored = described_class.restore_failure(data)

    expect(restored).to be_a(RSpec::Multicore::RemoteFailure)
    expect(restored.original_class_name).to eq("UnusualFailure")
    expect(restored.message).to eq("worker message")
  end

  it "preserves causes and aggregate children" do
    child = RuntimeError.new("child")
    parent = RuntimeError.new("parent")
    allow(parent).to receive(:cause).and_return(child)
    allow(parent).to receive(:all_exceptions).and_return([child])

    restored = described_class.restore_failure(described_class.failure(parent))

    expect(restored.cause.message).to eq("child")
    expect(restored.all_exceptions.map(&:message)).to eq(["child"])
  end
end
