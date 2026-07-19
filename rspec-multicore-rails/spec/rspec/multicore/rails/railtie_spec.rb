# frozen_string_literal: true

require "spec_helper"

RSpec.describe RSpec::Multicore::Rails::Railtie do
  before { RSpec::Multicore::Hooks.clear! }
  after { RSpec::Multicore::Hooks.clear! }

  it "registers only the ActiveRecord worker hook" do
    manager = instance_double(RSpec::Multicore::Rails::DatabaseManager, connect_worker: nil)
    allow(RSpec::Multicore::Rails::DatabaseManager).to receive(:new).and_return(manager)
    initializer = described_class.initializers.find do |entry|
      entry.name == "rspec_multicore_rails.active_record"
    end

    initializer.run(nil)
    RSpec::Multicore::Hooks.run_fork(4)

    expect(manager).to have_received(:connect_worker).with(4)
  end

  it "registers the multicore database tasks" do
    expect(described_class.rake_tasks).not_to be_empty
  end
end
