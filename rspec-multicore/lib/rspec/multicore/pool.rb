# frozen_string_literal: true

module RSpec
  module Multicore
    # Reaps workers, reports process failures, and guarantees child cleanup.
    module WorkerLifecycle
      private

      def reap_workers
        workers.each do |worker|
          _, status = Process.waitpid2(worker.pid)
          worker.status = status
          worker.completed = true
          next if status.success?
          next if @results.compact.include?(false) || @failures.any?

          @failures << Error.new("Worker #{worker.slot} exited with status #{status.exitstatus}")
        rescue Errno::ECHILD
          nil
        end
        @results.map! { _1.nil? ? false : _1 }
      end

      def report_failures
        @failures.each do |failure|
          @reporter.notify_non_example_exception(failure, "An error occurred in RSpec::Multicore.")
        end
      end

      def cleanup
        workers.each do |worker|
          next if worker.completed

          worker.channel.close
          Process.kill("TERM", worker.pid)
        rescue Errno::ESRCH
          nil
        end
        workers.each do |worker|
          next if worker.completed

          Process.waitpid(worker.pid)
          worker.completed = true
        rescue Errno::ECHILD
          worker.completed = true
          nil
        end
      end
    end

    # Schedules groups across persistent workers and replays ordered results.
    class Pool
      include WorkerLifecycle

      Worker = Struct.new(:pid, :slot, :channel, :assigned, :completed, :status, keyword_init: true)

      attr_reader :workers

      def initialize(reporter:, configuration:, workers: RSpec::Multicore.workers)
        @reporter = reporter
        @configuration = configuration
        @worker_count = workers
        @workers = []
        @failures = []
        @interrupt_handler = InterruptHandler.new(@workers)
      end

      def run(groups)
        return [] if groups.empty?

        prepare(groups)
        @interrupt_handler.install
        spawn_workers
        event_loop
        reap_workers
        report_failures
        @results
      rescue StandardError => e
        @failures << e
        report_failures
        Array.new(groups.size, false)
      ensure
        begin
          cleanup
        ensure
          @interrupt_handler.restore
        end
      end

      private

      def prepare(groups)
        @groups = groups
        @queue = (0...groups.size).to_a
        @results = Array.new(groups.size)
        @buffers = Hash.new { |hash, key| hash[key] = [] }
        @completed = {}
        @next_replay = 0
        registry = ObjectRegistry.new(groups)
        @bridge = ReporterBridge.new(registry, @reporter)
      end

      def spawn_workers
        [@worker_count, @groups.size].min.times do |index|
          parent_channel, child_channel = Channel.pair
          inherited_channels = workers.map(&:channel)
          pid = fork_worker(index, parent_channel, child_channel, inherited_channels)
          child_channel.close
          workers << Worker.new(pid:, slot: index + 1, channel: parent_channel)
        rescue StandardError
          parent_channel&.close
          child_channel&.close
          raise
        end
      end

      def fork_worker(index, parent_channel, child_channel, inherited_channels)
        Process.fork do
          @interrupt_handler.install_worker
          parent_channel.close
          inherited_channels.each(&:close)
          worker_main(index + 1, child_channel)
        end
      end

      def worker_main(slot, channel)
        ENV["RSPEC_MULTICORE_WORKER"] = slot.to_s
        writer = EventWriter.new(channel)
        reporter = ReporterProxy.new(writer)
        originals = install_worker_runtime(reporter, writer)
        failed = false

        begin
          Hooks.run_fork(slot)
          run_groups(channel, writer, reporter)
        rescue Exception => e # rubocop:disable Lint/RescueException
          failed = true
          safely_write(channel, [:worker_error, writer.group_index, Snapshot.failure(e)])
        ensure
          failed = shutdown_failed?(channel, slot) || failed
          restore_worker_runtime(originals)
          channel.close
          Process.exit!(failed ? 1 : 0)
        end
      end

      def install_worker_runtime(reporter, writer)
        originals = [$stdout, $stderr, @configuration.instance_variable_get(:@reporter)]
        $stdout = ProxyIO.new(writer, :stdout)
        $stderr = ProxyIO.new(writer, :stderr)
        @configuration.instance_variable_set(:@reporter, reporter)
        originals
      end

      def restore_worker_runtime(originals)
        $stdout, $stderr, reporter = originals
        @configuration.instance_variable_set(:@reporter, reporter)
      end

      def run_groups(channel, writer, reporter)
        loop do
          channel.write([:request_group])
          response = channel.read
          break if response.nil? || response.first == :no_more_groups

          index = response.fetch(1)
          writer.group_index = index
          result = @groups.fetch(index).run(reporter)
          channel.write([:group_done, index, !!result])
        end
      end

      def shutdown_failed?(channel, slot)
        Hooks.run_shutdown(slot).tap do |errors|
          errors.each { safely_write(channel, [:worker_error, nil, Snapshot.failure(_1)]) }
        end.any?
      end

      def safely_write(channel, frame)
        channel.write(frame)
      rescue StandardError
        nil
      end

      def event_loop
        active = workers.dup
        until active.empty?
          stop_queued_work if @interrupt_handler.interrupted?
          readable, = IO.select(active.map { _1.channel.socket }, nil, nil, 0.05)
          next unless readable

          readable.each do |socket|
            worker = active.find { _1.channel.socket.equal?(socket) }
            frame = worker.channel.read
            frame ? process_frame(worker, frame) : disconnect(worker, active)
          rescue StandardError => e
            @failures << e
            disconnect(worker, active)
          end
        end
        flush_completed
      end

      def process_frame(worker, frame)
        case frame.first
        when :request_group then assign_group(worker)
        when :event then buffer_event(frame)
        when :group_done then complete_group(worker, frame)
        when :worker_error then record_worker_error(worker, frame)
        else raise Error, "Unknown worker frame: #{frame.first.inspect}"
        end
      end

      def assign_group(worker)
        if @interrupt_handler.interrupted?
          stop_queued_work
          worker.assigned = nil
          worker.channel.write([:no_more_groups])
          return
        end

        index = @queue.shift
        if index
          worker.assigned = index
          worker.channel.write([:run_group, index])
        else
          worker.assigned = nil
          worker.channel.write([:no_more_groups])
        end
      end

      def stop_queued_work = @queue.shift(@queue.size).each { fail_group(_1) }

      def buffer_event(frame)
        _, group_index, sequence, event, payload = frame
        @buffers[group_index] << [sequence, event, payload]
      end

      def complete_group(worker, frame)
        index = frame.fetch(1)
        @results[index] = frame.fetch(2)
        @completed[index] = true
        worker.assigned = nil
        flush_completed
      end

      def record_worker_error(worker, frame)
        @failures << Snapshot.restore_failure(frame.fetch(2))
        fail_group(worker.assigned || frame[1])
        worker.assigned = nil
      end

      def disconnect(worker, active)
        if worker.assigned
          @failures << Error.new("Worker #{worker.slot} disconnected while running group #{worker.assigned}")
        end
        fail_group(worker.assigned)
        worker.assigned = nil
        worker.channel.close
        active.delete(worker)
      end

      def fail_group(index)
        return if index.nil?

        @results[index] = false
        @completed[index] = true
        flush_completed
      end

      def flush_completed
        while @completed[@next_replay]
          Array(@buffers.delete(@next_replay)).sort_by(&:first).each do |_, event, payload|
            @bridge.replay(event, payload)
          end
          @next_replay += 1
        end
      end
    end
  end
end
