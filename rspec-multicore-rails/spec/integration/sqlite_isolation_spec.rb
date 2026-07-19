# frozen_string_literal: true

require "spec_helper"
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

  def create_records(name)
    ActiveRecord::Base.connection.create_table(:records) { _1.string :name }
    ActiveRecord::Base.connection.execute("INSERT INTO records (name) VALUES ('#{name}')")
  end
end
