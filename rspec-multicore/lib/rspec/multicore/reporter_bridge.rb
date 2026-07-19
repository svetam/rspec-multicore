# frozen_string_literal: true

module RSpec
  module Multicore
    # Retains the parent's original RSpec groups and examples by stable ID.
    class ObjectRegistry
      def initialize(top_groups)
        groups = top_groups.flat_map { [_1, *_1.descendants] }.uniq(&:id)
        @groups = groups.to_h { [_1.id, _1] }
        @examples = groups.flat_map(&:examples).to_h { [_1.id, _1] }
      end

      def group(id) = @groups.fetch(id)
      def example(id) = @examples.fetch(id)
    end

    # Represents a worker exception whose original class cannot be reconstructed.
    class RemoteFailure < StandardError
      attr_reader :original_class_name, :cause, :all_exceptions

      def initialize(data, cause: nil, all_exceptions: [])
        @original_class_name = data.fetch(:class)
        @cause = cause
        @all_exceptions = all_exceptions
        super(data.fetch(:message))
        set_backtrace(data[:backtrace])
      end
    end

    # Converts execution results and exceptions to bounded plain-value state.
    module Snapshot
      RESULT_FIELDS = %i[status started_at finished_at run_time pending_message pending_fixed].freeze

      module_function

      def example(example, description: nil)
        result = example.execution_result
        data = RESULT_FIELDS.to_h { [_1, encode_value(result.public_send(_1))] }
        data[:exception] = failure(result.exception)
        data[:pending_exception] = failure(result.pending_exception)

        { id: example.id, description:, result: data }
      end

      def apply_example(example, data)
        description = data[:description]
        apply_description(example, description) if description && !description.empty?

        result = example.execution_result
        RESULT_FIELDS.each do |field|
          result.public_send("#{field}=", decode_value(data.fetch(:result)[field]))
        end
        result.exception = restore_failure(data.dig(:result, :exception))
        result.pending_exception = restore_failure(data.dig(:result, :pending_exception))
        example
      end

      def failure(exception, seen = {}.compare_by_identity)
        return unless exception
        return cycle_failure(exception) if seen[exception]

        seen = seen.dup
        seen[exception] = true
        children = exception.respond_to?(:all_exceptions) ? exception.all_exceptions : []
        {
          class: exception.class.name,
          message: exception.message,
          backtrace: exception.backtrace,
          cause: failure(exception.cause, seen),
          children: children.map { failure(_1, seen) }
        }
      end

      def restore_failure(data)
        return unless data

        cause = restore_failure(data[:cause])
        children = Array(data[:children]).map { restore_failure(_1) }
        exception = build_exception(data, children)
        exception.set_backtrace(data[:backtrace])
        attach_failure_details(exception, cause, children)
      rescue StandardError
        RemoteFailure.new(data, cause:, all_exceptions: children)
      end

      def encode_value(value) = value.is_a?(Time) ? { time: value.to_f } : value

      def decode_value(value) = value.is_a?(Hash) && value.key?(:time) ? Time.at(value[:time]) : value

      def runtime_description(example)
        description = example.metadata[:description].to_s
        return description unless description.empty?

        RSpec::Matchers.generated_description.to_s if generated_description?
      end

      def apply_description(example, description)
        metadata = example.metadata
        if metadata[:description].to_s.empty?
          metadata[:full_description] = "#{metadata[:full_description]}#{description}"
        end
        metadata[:description] = description
      end

      def generated_description?
        defined?(RSpec::Matchers) && RSpec::Matchers.respond_to?(:generated_description) &&
          !RSpec::Matchers.generated_description.to_s.empty?
      end

      def build_exception(data, children)
        klass = Object.const_get(data.fetch(:class))
        raise TypeError unless klass <= Exception

        children.empty? ? klass.new(data.fetch(:message)) : klass.new(children)
      rescue NameError, TypeError, ArgumentError
        RemoteFailure.new(data, all_exceptions: children)
      end

      def attach_failure_details(exception, cause, children)
        exception.define_singleton_method(:cause) { cause } if cause
        if children.any? && !exception.respond_to?(:all_exceptions)
          exception.define_singleton_method(:all_exceptions) { children }
        end
        exception
      end

      def cycle_failure(exception)
        { class: exception.class.name, message: exception.message, backtrace: exception.backtrace,
          cause: nil, children: [] }
      end
    end

    # Serializes worker reporter events with a shared monotonic sequence.
    class EventWriter
      attr_accessor :group_index

      def initialize(channel)
        @channel = channel
        @sequence = 0
        @lock = Mutex.new
      end

      def emit(event, payload)
        @lock.synchronize do
          @sequence += 1
          @channel.write([:event, group_index, @sequence, event, payload])
        end
      end
    end

    # Exposes only the reporter calls made by RSpec 3.13 example execution.
    class ReporterProxy
      GROUP_EVENTS = %i[example_group_started example_group_finished].freeze
      EXAMPLE_EVENTS = %i[example_started example_finished example_passed example_failed example_pending].freeze

      def initialize(writer)
        @writer = writer
        @descriptions = {}
      end

      GROUP_EVENTS.each do |event|
        define_method(event) { |group| @writer.emit(event, group.id) }
      end

      EXAMPLE_EVENTS.each do |event|
        define_method(event) { |example| @writer.emit(event, snapshot(example)) }
      end

      def message(message) = @writer.emit(:message, message.to_s)
      def deprecation(*args) = @writer.emit(:deprecation, args)

      def notify_non_example_exception(exception, context)
        @writer.emit(:notify_non_example_exception, [Snapshot.failure(exception), context.to_s])
      end

      def fail_fast_limit_met? = false

      def method_missing(name, *) = raise UnsupportedReporterEvent, "Unsupported RSpec reporter event: #{name}"

      def respond_to_missing?(*, **) = false

      private

      def snapshot(example)
        original = @descriptions.fetch(example.id) do
          @descriptions[example.id] = example.metadata[:description].to_s
        end
        description = Snapshot.runtime_description(example)
        description = nil if description == original
        Snapshot.example(example, description:)
      end
    end

    # Sends worker stdout and stderr through the same ordered event writer.
    class ProxyIO
      def initialize(writer, stream)
        @writer = writer
        @stream = stream
      end

      def write(data)
        value = data.to_s
        return 0 if value.empty?

        @writer.emit(@stream, value)
        value.bytesize
      end

      def <<(data) = write(data).then { self }
      def flush = self
      def print(*args) = args.each { write(_1) }.then { nil }
      def printf(format, *args) = write(format % args).then { nil }
      def puts(*args) = (args.empty? ? write("\n") : args.each { write("#{_1}\n") }).then { nil }
      def tty? = false
      alias isatty tty?
      def sync = true

      def sync=(_value)
        true
      end

      def close = nil
      def closed? = false
    end

    # Restores parent objects and invokes the real RSpec reporter.
    class ReporterBridge
      GROUP_EVENTS = ReporterProxy::GROUP_EVENTS
      EXAMPLE_EVENTS = ReporterProxy::EXAMPLE_EVENTS

      def initialize(registry, reporter, stdout: $stdout, stderr: $stderr)
        @registry = registry
        @reporter = reporter
        @stdout = stdout
        @stderr = stderr
      end

      def replay(event, payload)
        case event
        when *GROUP_EVENTS then @reporter.public_send(event, @registry.group(payload))
        when *EXAMPLE_EVENTS then replay_example(event, payload)
        when :message then @reporter.message(payload)
        when :deprecation then @reporter.deprecation(*payload)
        when :notify_non_example_exception then replay_error(payload)
        when :stdout then @stdout.write(payload)
        when :stderr then @stderr.write(payload)
        else raise UnsupportedReporterEvent, "Unsupported RSpec reporter event: #{event}"
        end
      end

      private

      def replay_example(event, payload)
        example = @registry.example(payload.fetch(:id))
        @reporter.public_send(event, Snapshot.apply_example(example, payload))
      end

      def replay_error(payload)
        @reporter.notify_non_example_exception(Snapshot.restore_failure(payload[0]),
                                               payload[1])
      end
    end
  end
end
