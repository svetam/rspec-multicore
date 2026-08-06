# frozen_string_literal: true

require "spec_helper"

RSpec.describe RSpec::Multicore::Rails::DatabaseManager do
  let(:base_config) do
    config("primary", database: "portal_test", adapter: "postgresql", host: "localhost")
  end
  let(:animals_config) { config("animals", database: "animals_test", adapter: "postgresql") }
  let(:replica_config) do
    config("primary_replica", database: "portal_test", adapter: "postgresql", replica: true)
  end
  let(:external_config) do
    config("external", database: "external_test", adapter: "postgresql", database_tasks: false)
  end
  let(:configurations) { [base_config, animals_config, replica_config, external_config] }

  before do
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("test"))
    allow(ActiveRecord::Base).to receive(:connection_db_config).and_return(base_config)
    allow(ActiveRecord::Base.configurations).to receive(:configs_for)
      .with(env_name: "test", include_hidden: true).and_return(configurations)
    allow(RSpec::Multicore).to receive(:workers).and_return(3)
  end

  subject(:manager) { described_class.new }

  it "uses the core worker count and suffixes server databases" do
    expect(manager.workers).to eq(3)
    expect(manager.database_for(1)).to eq("portal_test")
    expect(manager.database_for(2)).to eq("portal_test_2")
    expect(manager.database_for(3, animals_config)).to eq("animals_test_3")
  end

  it "places SQLite suffixes before the extension" do
    sqlite = config("primary", database: "tmp/portal_test.sqlite3", adapter: "sqlite3")
    allow(ActiveRecord::Base).to receive(:connection_db_config).and_return(sqlite)
    allow(ActiveRecord::Base.configurations).to receive(:configs_for).and_return([sqlite])

    expect(described_class.new.database_for(4)).to eq("tmp/portal_test_4.sqlite3")
  end

  it "routes every test configuration to the worker and restores the base names" do
    handler = instance_double(ActiveRecord::ConnectionAdapters::ConnectionHandler)
    allow(ActiveRecord::Base).to receive(:connection_handler).and_return(handler)
    allow(ActiveRecord::Base).to receive(:establish_connection)
    allow(handler).to receive(:clear_all_connections!)

    manager.connect_worker(2)

    expect(configurations.map(&:database)).to eq(
      %w[portal_test_2 animals_test_2 portal_test_2 external_test_2]
    )
    expect(handler).to have_received(:clear_all_connections!).once
    expect(ActiveRecord::Base).to have_received(:establish_connection).with(base_config).once

    manager.connect_worker(1)

    expect(configurations.map(&:database)).to eq(
      %w[portal_test animals_test portal_test external_test]
    )
  end

  it "prepares only writable suffixed databases" do
    purged = []
    loaded = []
    allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:purge) { purged << [_1.name, _1.database] }
    allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:load_schema) do |config, format|
      loaded << [config.name, config.database, format]
    end

    manager.prepare_workers

    expect(purged).to contain_exactly(
      %w[primary portal_test_2],
      %w[primary portal_test_3],
      %w[animals animals_test_2],
      %w[animals animals_test_3]
    )
    expect(loaded.map { _1.take(2) }).to match_array(purged)
    expect(loaded.map(&:last)).to all(eq(:ruby))
  end

  it "filters database tasks by configuration name" do
    dropped = []
    allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:drop) { dropped << [_1.name, _1.database] }

    manager.drop_workers(name: "animals")

    expect(dropped).to eq([%w[animals animals_test_2], %w[animals animals_test_3]])
  end

  it "creates a missing database while purging" do
    allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:purge).and_raise(ActiveRecord::NoDatabaseError)
    allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:create)

    manager.purge_workers(name: "primary")

    expect(ActiveRecord::Tasks::DatabaseTasks).to have_received(:create).twice
  end

  it "does no database work when fewer than two workers are configured" do
    allow(RSpec::Multicore).to receive(:workers).and_return(0)
    allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:purge)

    manager.prepare_workers

    expect(ActiveRecord::Tasks::DatabaseTasks).not_to have_received(:purge)
  end

  it "allows task operations outside test while refusing worker connections" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("development"))
    allow(ActiveRecord::Tasks::DatabaseTasks).to receive(:drop)

    expect { manager.drop_workers }.not_to raise_error
    expect { manager.connect_worker(2) }.to raise_error(RSpec::Multicore::Error, /test environment/)
  end

  def config(name, **configuration)
    ActiveRecord::DatabaseConfigurations::HashConfig.new(
      "test",
      name,
      { schema_format: :ruby }.merge(configuration)
    )
  end
end
