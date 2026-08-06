# frozen_string_literal: true

require "active_record"
require "active_record/tasks/database_tasks"

module RSpec
  module Multicore
    module Rails
      # Manages and connects worker-owned ActiveRecord test databases.
      class DatabaseManager
        TEST_ENV = "test"

        def initialize
          @primary_config = ActiveRecord::Base.connection_db_config
          @configs = test_configs
          @configs << @primary_config unless @configs.include?(@primary_config)
          @base_databases = {}.compare_by_identity
          @configs.each { @base_databases[_1] = _1.database }
        end

        def connect_worker(slot)
          ensure_test_environment!
          ActiveRecord::Base.connection_handler.clear_all_connections!
          @configs.each { _1._database = database_for(slot, _1) }
          ActiveRecord::Base.establish_connection(@primary_config)
        end

        def create_workers(name: nil) = each_worker_config(name:) { database_tasks.create(_1) }

        def purge_workers(name: nil)
          each_worker_config(name:) do |config|
            database_tasks.purge(config)
          rescue ActiveRecord::NoDatabaseError
            database_tasks.create(config)
          end
        end

        def load_schema_workers(name: nil)
          each_worker_config(name:) do |config|
            database_tasks.load_schema(config, schema_format(config))
          end
        end

        def prepare_workers(name: nil)
          purge_workers(name:)
          load_schema_workers(name:)
        end

        def drop_workers(name: nil) = each_worker_config(name:) { database_tasks.drop(_1) }

        def workers = RSpec::Multicore.workers

        def database_for(slot, config = @primary_config)
          return base_database(config) if slot == 1

          database = base_database(config)
          return "#{database}_#{slot}" unless config.adapter == "sqlite3"

          extension = File.extname(database)
          "#{database.delete_suffix(extension)}_#{slot}#{extension}"
        end

        private

        def test_configs
          configurations = ActiveRecord::Base.configurations
          Array(configurations.configs_for(env_name: TEST_ENV, include_hidden: true))
        end

        def task_configs(name: nil)
          @configs.select do |config|
            config.env_name == TEST_ENV && config.database_tasks? && (!name || config.name == name)
          end
        end

        def each_worker_config(name:)
          return enum_for(__method__, name:) unless block_given?

          task_configs(name:).each do |config|
            2.upto(workers) { yield derived_config(config, _1) }
          end
        end

        def derived_config(config, slot)
          ActiveRecord::DatabaseConfigurations::HashConfig.new(
            config.env_name,
            config.name,
            config.configuration_hash.merge(database: database_for(slot, config))
          )
        end

        def base_database(config) = @base_databases.fetch(config)
        def database_tasks = ActiveRecord::Tasks::DatabaseTasks

        def schema_format(config)
          return config.schema_format if config.respond_to?(:schema_format)

          config.configuration_hash.fetch(:schema_format, ActiveRecord.schema_format)
        end

        def ensure_test_environment!
          return if ::Rails.env.test?

          raise RSpec::Multicore::Error, "Parallel databases can only be connected in the Rails test environment"
        end
      end
    end
  end
end
