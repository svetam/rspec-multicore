# frozen_string_literal: true

require "rspec/multicore/rails"

namespace :db do
  namespace :test do
    namespace :multicore do
      desc "Prepare all parallel test databases (create and load schema)"
      task prepare: :environment do
        manager = RSpec::Multicore::Rails::DatabaseManager.new
        puts "Preparing parallel test databases..."
        manager.prepare_all
        puts "Parallel test databases ready (#{manager.workers} workers)"
      end

      desc "Drop all parallel test databases (except base test database)"
      task drop: :environment do
        manager = RSpec::Multicore::Rails::DatabaseManager.new
        puts "Dropping parallel test databases..."
        manager.drop_workers
        puts "Parallel test databases dropped"
      end

      desc "Recreate all parallel test databases"
      task recreate: :prepare
    end
  end
end
