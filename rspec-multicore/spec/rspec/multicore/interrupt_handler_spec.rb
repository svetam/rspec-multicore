# frozen_string_literal: true

RSpec.describe RSpec::Multicore::InterruptHandler do
  it "signals every live worker and ignores workers that were already reaped" do
    workers = [
      RSpec::Multicore::Pool::Worker.new(pid: 123, slot: 1),
      RSpec::Multicore::Pool::Worker.new(pid: 456, slot: 2, completed: true)
    ]
    handler = described_class.new(workers)
    allow(Process).to receive(:kill)

    handler.send(:signal_workers, "INT")

    expect(Process).to have_received(:kill).with("INT", 123)
    expect(Process).not_to have_received(:kill).with("INT", 456)
  end

  it "immediately kills every live worker when a force quit is requested" do
    workers = [RSpec::Multicore::Pool::Worker.new(pid: 123, slot: 1)]
    handler = described_class.new(workers)
    handler.instance_variable_set(:@interrupted, true)
    allow(Process).to receive(:kill)

    handler.send(:handle)

    expect(handler).to be_force_quit
    expect(Process).to have_received(:kill).with("KILL", 123)
  end

  it "reaps every live worker before delegating a force quit" do
    workers = [RSpec::Multicore::Pool::Worker.new(pid: 123, slot: 1)]
    handler = described_class.new(workers)
    events = []
    handler.instance_variable_set(:@original_handler, -> { events << :delegate })
    allow(Process).to receive(:waitpid) { events << :reap }
    allow(Process).to receive(:exit!) { events << :exit }

    handler.force_quit

    expect(events).to eq(%i[reap delegate exit])
    expect(workers.first.completed).to be(true)
  end
end
