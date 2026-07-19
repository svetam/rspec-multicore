# frozen_string_literal: true

require "etc"

module RSpec
  # Process configuration and lifecycle hooks for multicore RSpec execution.
  module Multicore
    # Resolves the worker count from the Ruby API and RSPEC_MULTICORE.
    class Configuration
      ENABLED_VALUES = %w[true on auto].freeze
      DISABLED_VALUES = %w[0 false off].freeze

      def workers
        setting = env_value
        case setting
        when :disabled then 0
        when Integer then setting
        else @workers || Etc.nprocessors
        end
      end

      def workers=(value)
        unless value.nil? || (value.is_a?(Integer) && value.positive?)
          raise ArgumentError, "workers must be a positive integer or nil"
        end

        @workers = value
      end

      private

      def env_value
        value = ENV.fetch("RSPEC_MULTICORE", nil)
        return :default if value.nil? || ENABLED_VALUES.include?(value.downcase)
        return :disabled if DISABLED_VALUES.include?(value.downcase)

        workers = Integer(value, 10)
        return workers if workers.positive?

        raise ArgumentError
      rescue ArgumentError
        raise ArgumentError,
              "RSPEC_MULTICORE must be auto, true, on, false, off, 0, or a positive integer"
      end
    end

    # Stores process lifecycle hooks independently of RSpec configuration.
    module Hooks
      class << self
        def on_fork(&block) = (fork_hooks << block if block)

        def on_shutdown(&block) = (shutdown_hooks << block if block)

        def run_fork(slot) = fork_hooks.each { _1.call(slot) }

        def run_shutdown(slot)
          shutdown_hooks.reverse_each.filter_map do |hook|
            hook.call(slot)
            nil
          rescue StandardError => e
            e
          end
        end

        def clear!
          fork_hooks.clear
          shutdown_hooks.clear
        end

        private

        def fork_hooks = @fork_hooks ||= []
        def shutdown_hooks = @shutdown_hooks ||= []
      end
    end

    class << self
      def configuration = @configuration ||= Configuration.new

      def configure = yield configuration

      def workers = configuration.workers
      def enabled? = workers.positive?
      def on_worker_fork(&) = Hooks.on_fork(&)
      def on_worker_shutdown(&) = Hooks.on_shutdown(&)
    end
  end
end
