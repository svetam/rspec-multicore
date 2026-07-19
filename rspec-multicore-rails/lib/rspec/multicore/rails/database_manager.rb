# frozen_string_literal: true

require "active_record"
require "active_record/tasks/database_tasks"

module RSpec
  module Multicore
    module Rails
      # Names, prepares, and connects worker-owned ActiveRecord databases.
      class DatabaseManager
        def initialize
          ensure_test_environment!
          @base_config = ActiveRecord::Base.connection_db_config
        end

        def connect_worker(slot)
          ActiveRecord::Base.connection_handler.clear_all_connections!
          ActiveRecord::Base.establish_connection(config_for(slot))
        end

        def prepare_all
          worker_slots.each do |slot|
            purge(slot)
            ActiveRecord::Tasks::DatabaseTasks.load_schema(hash_config_for(slot))
          end
        end

        def drop_workers = worker_slots.drop(1).each { drop(_1) }

        def workers = RSpec::Multicore.workers
        def database_for(slot) = slot == 1 ? base_database : suffixed_database(slot)

        private

        def worker_slots = (1..workers)
        def base_database = @base_config.database

        def suffixed_database(slot)
          if sqlite?
            extension = File.extname(base_database)
            return "#{base_database.delete_suffix(extension)}_#{slot}#{extension}"
          end

          "#{base_database}_#{slot}"
        end

        def sqlite? = @base_config.adapter == "sqlite3"

        def config_for(slot) = @base_config.configuration_hash.merge(database: database_for(slot))

        def hash_config_for(slot)
          ActiveRecord::DatabaseConfigurations::HashConfig.new(
            @base_config.env_name,
            @base_config.name,
            config_for(slot)
          )
        end

        def purge(slot)
          drop(slot)
          ActiveRecord::Tasks::DatabaseTasks.create(config_for(slot))
        end

        def drop(slot)
          ActiveRecord::Tasks::DatabaseTasks.drop(config_for(slot))
        rescue ActiveRecord::NoDatabaseError
          nil
        end

        def ensure_test_environment!
          return if ::Rails.env.test?

          raise RSpec::Multicore::Error, "Parallel databases can only be managed in the Rails test environment"
        end
      end
    end
  end
end
