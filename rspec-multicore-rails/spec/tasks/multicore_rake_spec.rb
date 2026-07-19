# frozen_string_literal: true

require "spec_helper"
require "rake"

RSpec.describe "multicore rake tasks" do
  let(:rake) { Rake::Application.new }
  let(:manager) { instance_double(RSpec::Multicore::Rails::DatabaseManager) }

  before do
    Rake.application = rake
    load File.expand_path("../../lib/tasks/multicore.rake", __dir__)
    Rake::Task.define_task(:environment)
    allow(RSpec::Multicore::Rails::DatabaseManager).to receive(:new).and_return(manager)
    allow(manager).to receive(:workers).and_return(4)
  end

  after do
    Rake.application.clear
  end

  describe "db:test:multicore:prepare" do
    let(:task) { Rake::Task["db:test:multicore:prepare"] }

    it "exists" do
      expect(task).not_to be_nil
    end

    it "depends on :environment" do
      expect(task.prerequisites).to include("environment")
    end

    it "calls prepare_all" do
      expect(manager).to receive(:prepare_all)

      expect { task.invoke }.to output(/Parallel test databases ready/).to_stdout
    end
  end

  describe "db:test:multicore:drop" do
    let(:task) { Rake::Task["db:test:multicore:drop"] }

    it "exists" do
      expect(task).not_to be_nil
    end

    it "depends on :environment" do
      expect(task.prerequisites).to include("environment")
    end

    it "drops parallel databases" do
      expect(manager).to receive(:drop_workers)

      expect { task.invoke }.to output(/Parallel test databases dropped/).to_stdout
    end
  end

  describe "db:test:multicore:recreate" do
    let(:task) { Rake::Task["db:test:multicore:recreate"] }

    it "exists" do
      expect(task).not_to be_nil
    end

    it "depends on prepare" do
      expect(task.prerequisites).to include("prepare")
    end

    it "runs the prepare task" do
      expect(manager).to receive(:prepare_all)

      expect { task.invoke }.to output(/Parallel test databases ready/).to_stdout
    end
  end
end
