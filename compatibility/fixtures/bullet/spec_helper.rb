# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

require "active_record/railtie"
require "bullet"
require "logger"
require "pathname"
require "rspec/multicore/rails"
require_relative "../support"

class CompatibilityBulletApplication < Rails::Application
  config.root = Pathname.new(__dir__)
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.secret_key_base = "rspec-multicore-bullet"
end

CompatibilityBulletApplication.initialize!

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ENV.fetch("DATABASE_PATH"))
manager = RSpec::Multicore::Rails::DatabaseManager.new
(1..[RSpec::Multicore.workers, 1].max).each do |slot|
  manager.connect_worker(slot)
  ActiveRecord::Base.connection.create_table(:authors, force: true) { _1.string :name }
  ActiveRecord::Base.connection.create_table(:books, force: true) do |table|
    table.string :title
    table.integer :author_id
  end
end
manager.connect_worker(1)

class CompatibilityAuthor < ActiveRecord::Base
  self.table_name = "authors"
  has_many :books, class_name: "CompatibilityBook", foreign_key: :author_id, inverse_of: :author
end

class CompatibilityBook < ActiveRecord::Base
  self.table_name = "books"
  belongs_to :author, class_name: "CompatibilityAuthor", inverse_of: :books
end

Bullet.enable = true
Bullet.n_plus_one_query_enable = true

RSpec.configure do |config|
  config.before { Bullet.start_request }
  config.after do
    Bullet.perform_out_of_channel_notifications if Bullet.notification?
  ensure
    Bullet.end_request
  end
end
