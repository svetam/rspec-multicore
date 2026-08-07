# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"

RSpec.describe "SQLite worker isolation" do
  it "connects workers to distinct database files" do
    Dir.mktmpdir("rspec-multicore") do |directory|
      base_database = File.join(directory, "app_test.sqlite3")
      allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("test"))
      ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: base_database)
      manager = RSpec::Multicore::Rails::DatabaseManager.new

      manager.connect_worker(1)
      create_records("base")
      manager.connect_worker(2)
      create_records("worker")

      expect(File).to exist(base_database)
      expect(File).to exist(File.join(directory, "app_test_2.sqlite3"))
      expect(ActiveRecord::Base.connection.select_value("SELECT name FROM records")).to eq("worker")

      manager.connect_worker(1)
      expect(ActiveRecord::Base.connection.select_value("SELECT name FROM records")).to eq("base")
    ensure
      ActiveRecord::Base.connection_handler.clear_all_connections!
    end
  end

  it "creates, purges, and drops only suffixed worker databases" do
    Dir.mktmpdir("rspec-multicore-tasks") do |directory|
      base_database = File.join(directory, "app_test.sqlite3")
      with_sqlite_configuration(base_database) do
        allow(RSpec::Multicore).to receive(:workers).and_return(3)
        manager = RSpec::Multicore::Rails::DatabaseManager.new

        manager.create_workers
        expect(worker_databases(base_database)).to all(satisfy { File.exist?(_1) })

        manager.connect_worker(2)
        create_records("worker")
        manager.purge_workers
        manager.connect_worker(2)
        expect(ActiveRecord::Base.connection.tables).not_to include("records")

        manager.drop_workers
        expect(worker_databases(base_database).select { File.exist?(_1) }).to be_empty
      end
    end
  end

  it "loads schemas into every worker and restores the base connection" do
    Dir.mktmpdir("rspec-multicore-schema") do |directory|
      base_database = File.join(directory, "app_test.sqlite3")
      with_sqlite_configuration(base_database) do
        allow(RSpec::Multicore).to receive(:workers).and_return(3)
        schema_directory = File.join(directory, "db")
        FileUtils.mkdir_p(schema_directory)
        File.write(
          File.join(schema_directory, "schema.rb"),
          <<~RUBY
            ActiveRecord::Schema[7.1].define do
              create_table :schema_markers do |table|
                table.string :name
              end
            end
          RUBY
        )
        with_database_tasks_directory(schema_directory) do
          ActiveRecord::Base.connection.create_table(:base_markers) { _1.string :name }
          manager = RSpec::Multicore::Rails::DatabaseManager.new

          manager.create_workers
          expect(ActiveRecord::Base.connection_db_config.database).to eq(base_database)

          manager.load_schema_workers
          expect(ActiveRecord::Base.connection_db_config.database).to eq(base_database)
          expect(ActiveRecord::Base.connection.tables).to include("base_markers")
          expect(ActiveRecord::Base.connection.tables).not_to include("schema_markers")

          [2, 3].each do |slot|
            manager.connect_worker(slot)
            expect(ActiveRecord::Base.connection.tables).to include("schema_markers")
          end

          manager.connect_worker(1)
          manager.purge_workers
          expect(ActiveRecord::Base.connection_db_config.database).to eq(base_database)
          manager.drop_workers
          expect(ActiveRecord::Base.connection_db_config.database).to eq(base_database)
          expect(worker_databases(base_database).select { File.exist?(_1) }).to be_empty
        end
      end
    end
  end

  def create_records(name)
    ActiveRecord::Base.connection.create_table(:records) { _1.string :name }
    ActiveRecord::Base.connection.execute("INSERT INTO records (name) VALUES ('#{name}')")
  end

  def with_sqlite_configuration(database)
    previous = ActiveRecord::Base.configurations
    ActiveRecord::Base.configurations = {
      "test" => { "primary" => { "adapter" => "sqlite3", "database" => database } }
    }
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("test"))
    ActiveRecord::Base.establish_connection(:test)
    yield
  ensure
    ActiveRecord::Base.connection_handler.clear_all_connections!
    ActiveRecord::Base.configurations = previous
  end

  def with_database_tasks_directory(directory)
    database_tasks = ActiveRecord::Tasks::DatabaseTasks
    previous = database_tasks.instance_variable_get(:@db_dir)
    database_tasks.db_dir = directory
    yield
  ensure
    database_tasks.db_dir = previous
  end

  def worker_databases(base) = [2, 3].map { "#{base.delete_suffix(".sqlite3")}_#{_1}.sqlite3" }
end
