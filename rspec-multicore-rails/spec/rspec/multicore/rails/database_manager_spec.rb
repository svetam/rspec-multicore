# frozen_string_literal: true

require "spec_helper"

RSpec.describe RSpec::Multicore::Rails::DatabaseManager do
  let(:base_config) do
    instance_double(
      ActiveRecord::DatabaseConfigurations::HashConfig,
      adapter: "postgresql",
      database: "portal_test",
      env_name: "test",
      name: "primary",
      configuration_hash: { adapter: "postgresql", database: "portal_test", host: "localhost" }
    )
  end

  before do
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("test"))
    allow(ActiveRecord::Base).to receive(:connection_db_config).and_return(base_config)
    allow(RSpec::Multicore).to receive(:workers).and_return(3)
  end

  subject(:manager) { described_class.new }

  it "uses the core worker count and suffixes server databases" do
    expect(manager.workers).to eq(3)
    expect(manager.database_for(1)).to eq("portal_test")
    expect(manager.database_for(2)).to eq("portal_test_2")
  end

  it "places SQLite suffixes before the extension" do
    allow(base_config).to receive_messages(adapter: "sqlite3", database: "tmp/portal_test.sqlite3")

    expect(manager.database_for(4)).to eq("tmp/portal_test_4.sqlite3")
  end

  it "clears inherited connections before establishing the worker connection" do
    handler = instance_double(ActiveRecord::ConnectionAdapters::ConnectionHandler)
    allow(ActiveRecord::Base).to receive(:connection_handler).and_return(handler)

    expect(handler).to receive(:clear_all_connections!).ordered
    expect(ActiveRecord::Base).to receive(:establish_connection)
      .with({ adapter: "postgresql", database: "portal_test_2", host: "localhost" }).ordered

    manager.connect_worker(2)
  end

  it "prepares every database and drops only suffixed databases" do
    allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:drop)
    allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:create)
    allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:load_schema)

    manager.prepare_all
    manager.drop_workers

    expect(ActiveRecord::Tasks::DatabaseTasks).to have_received(:load_schema).exactly(3).times
    expect(ActiveRecord::Tasks::DatabaseTasks).to have_received(:drop).exactly(5).times
  end

  it "ignores a missing database while preparing or dropping" do
    allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:drop).and_raise(ActiveRecord::NoDatabaseError)
    allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:create)
    allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:load_schema)

    expect { manager.prepare_all }.not_to raise_error
  end

  it "refuses to manage databases outside the test environment" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("development"))

    expect { described_class.new }.to raise_error(RSpec::Multicore::Error, /test environment/)
  end
end
