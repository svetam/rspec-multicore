# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

require "active_record/railtie"
require "database_cleaner/active_record"
require "factory_bot_rails"
require "logger"
require "pathname"
require "rspec/multicore/rails"
require_relative "../support"

class CompatibilityRailsApplication < Rails::Application
  config.root = Pathname.new(__dir__)
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.secret_key_base = "rspec-multicore-compatibility"
end

CompatibilityRailsApplication.initialize!

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ENV.fetch("DATABASE_PATH"))
manager = RSpec::Multicore::Rails::DatabaseManager.new
(1..[RSpec::Multicore.workers, 1].max).each do |slot|
  manager.connect_worker(slot)
  ActiveRecord::Base.connection.create_table(:widgets, force: true) { _1.string :name }
end
manager.connect_worker(1)

class CompatibilityWidget < ActiveRecord::Base
  self.table_name = "widgets"
end

FactoryBot.define do
  factory :compatibility_widget do
    sequence(:name) { "widget-#{_1}" }
  end
end

DatabaseCleaner[:active_record].strategy = :transaction

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.around do |example|
    DatabaseCleaner[:active_record].cleaning { example.run }
  end
end
