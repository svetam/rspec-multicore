# frozen_string_literal: true

module RSpec
  module Multicore
    # Coordinates RSpec's two-stage interrupt behavior across forked workers.
    class InterruptHandler
      def initialize(workers)
        @workers = workers
        @interrupted = false
      end

      def install
        @interrupted = false
        @original_handler = Signal.trap("INT") { handle }
      end

      def restore
        return unless @original_handler

        Signal.trap("INT", @original_handler)
        @original_handler = nil
      end

      def install_worker = Signal.trap("INT") { RSpec.world.wants_to_quit = true }

      def interrupted? = @interrupted

      private

      def handle
        return force_quit if interrupted?

        @interrupted = true
        invoke_original_handler
        RSpec::Core::Runner.handle_interrupt unless RSpec.world.wants_to_quit
        signal_workers("INT")
      end

      def force_quit
        signal_workers("KILL")
        invoke_original_handler
        Process.exit!(1)
      end

      def invoke_original_handler = (@original_handler.call if @original_handler.respond_to?(:call))

      def signal_workers(signal)
        @workers.each do |worker|
          next if worker.completed

          Process.kill(signal, worker.pid)
        rescue Errno::ESRCH
          nil
        end
      end
    end
  end
end
