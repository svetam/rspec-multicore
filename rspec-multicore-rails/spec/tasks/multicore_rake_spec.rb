# frozen_string_literal: true

require "spec_helper"
require "rake"

RSpec.describe "Rails database task enhancements" do
  let(:rake) { Rake::Application.new }
  let(:manager) { instance_double(RSpec::Multicore::Rails::DatabaseManager) }

  before do
    Rake.application = rake
    @events = []
    define_rails_tasks
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("test"))
    allow(RSpec::Multicore::Rails::DatabaseManager).to receive(:new).and_return(manager)
    allow(manager).to receive_messages(
      create_workers: nil,
      prepare_workers: nil,
      purge_workers: nil,
      load_schema_workers: nil,
      drop_workers: nil
    )
    load File.expand_path("../../lib/tasks/multicore.rake", __dir__)
  end

  after { Rake.application.clear }

  it "appends worker preparation after Rails db:prepare" do
    allow(manager).to receive(:prepare_workers) { @events << :workers }

    Rake::Task["db:prepare"].invoke

    expect(@events).to eq(%i[rails workers])
  end

  it "enhances aggregate create, schema, purge, and drop tasks" do
    Rake::Task["db:create"].invoke
    Rake::Task["db:schema:load"].invoke
    Rake::Task["db:purge"].invoke
    Rake::Task["db:drop"].invoke

    expect(manager).to have_received(:create_workers).with(name: nil)
    expect(manager).to have_received(:load_schema_workers).with(name: nil)
    expect(manager).to have_received(:purge_workers).with(name: nil)
    expect(manager).to have_received(:drop_workers).with(name: nil)
  end

  it "uses the native test task graph exactly once" do
    Rake::Task["db:test:prepare"].invoke

    expect(manager).to have_received(:purge_workers).with(name: nil).once
    expect(manager).to have_received(:load_schema_workers).with(name: nil).once
    expect(manager).not_to have_received(:prepare_workers)
  end

  it "uses the native setup task graph exactly once" do
    Rake::Task["db:setup"].invoke

    expect(manager).to have_received(:create_workers).with(name: nil).once
    expect(manager).to have_received(:load_schema_workers).with(name: nil).once
  end

  it "uses the native reset task graph exactly once" do
    Rake::Task["db:reset"].invoke

    expect(manager).to have_received(:drop_workers).with(name: nil).once
    expect(manager).to have_received(:create_workers).with(name: nil).once
    expect(manager).to have_received(:load_schema_workers).with(name: nil).once
  end

  it "enhances named multi-database tasks" do
    Rake::Task["db:test:prepare:animals"].invoke
    Rake::Task["db:create:animals"].invoke
    Rake::Task["db:drop:animals"].invoke

    expect(manager).to have_received(:purge_workers).with(name: "animals").once
    expect(manager).to have_received(:load_schema_workers).with(name: "animals").once
    expect(manager).to have_received(:create_workers).with(name: "animals").once
    expect(manager).to have_received(:drop_workers).with(name: "animals").once
  end

  it "skips current-environment tasks when Rails is not managing test" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))

    Rake::Task["db:prepare"].invoke
    Rake::Task["db:create:animals"].invoke

    expect(manager).not_to have_received(:prepare_workers)
    expect(manager).not_to have_received(:create_workers)
  end

  it "skips test during development when Rails is configured to skip it" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("development"))
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("SKIP_TEST_DATABASE").and_return("1")

    Rake::Task["db:prepare"].invoke

    expect(manager).not_to have_received(:prepare_workers)
  end

  it "matches Rails development scope for aggregate but not named tasks" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("development"))

    Rake::Task["db:create"].invoke
    Rake::Task["db:create:animals"].invoke

    expect(manager).to have_received(:create_workers).with(name: nil).once
    expect(manager).not_to have_received(:create_workers).with(name: "animals")
  end

  it "always enhances all-environment and explicit test tasks" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))

    Rake::Task["db:create:all"].invoke
    Rake::Task["db:test:purge"].invoke

    expect(manager).to have_received(:create_workers).with(name: nil)
    expect(manager).to have_received(:purge_workers).with(name: nil)
  end

  it "does not define the removed multicore task namespace" do
    expect(Rake::Task.task_defined?("db:test:multicore:prepare")).to be(false)
    expect(Rake::Task.task_defined?("db:test:multicore:drop")).to be(false)
    expect(Rake::Task.task_defined?("db:test:multicore:recreate")).to be(false)
  end

  def define_rails_tasks
    %w[
      db:create db:create:all db:create:animals db:schema:load db:schema:load:animals
      db:purge db:purge:all db:drop db:drop:all db:drop:_unsafe db:drop:animals
      db:test:purge db:test:purge:animals
    ].each { Rake::Task.define_task(_1) }

    Rake::Task.define_task("db:prepare") { @events << :rails }
    Rake::Task.define_task("db:setup" => ["db:create", "db:schema:load"])
    Rake::Task.define_task("db:reset" => ["db:drop", "db:setup"])
    Rake::Task.define_task("db:test:load_schema" => "db:test:purge")
    Rake::Task.define_task("db:test:load_schema:animals" => "db:test:purge:animals")
    Rake::Task.define_task("db:test:prepare") { Rake::Task["db:test:load_schema"].invoke }
    Rake::Task.define_task("db:test:prepare:animals") { Rake::Task["db:test:load_schema:animals"].invoke }
  end
end
