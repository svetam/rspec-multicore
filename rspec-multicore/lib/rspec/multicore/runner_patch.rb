# frozen_string_literal: true

module RSpec
  module Multicore
    # Enumerable wrapper that substitutes parallel work only for RSpec's map call.
    class ParallelGroups
      include Enumerable

      def initialize(groups, configuration)
        @groups = groups
        @configuration = configuration
      end

      def each(&block) = block ? @groups.each(&block) : enum_for(:each)

      def map
        return enum_for(:map) unless block_given?

        Pool.new(reporter: @configuration.reporter, configuration: @configuration).run(@groups)
      end
    end

    # The only RSpec method override used by rspec-multicore.
    module RunnerPatch
      def run_specs(example_groups)
        return super unless parallelize?(example_groups)

        super(ParallelGroups.new(example_groups, @configuration))
      end

      private

      def parallelize?(groups)
        RSpec::Multicore.workers > 1 && groups.size > 1 && Process.respond_to?(:fork) &&
          !@configuration.fail_fast && !@configuration.dry_run?
      end
    end
  end
end

RSpec::Core::Runner.prepend(RSpec::Multicore::RunnerPatch) unless RSpec::Core::Runner < RSpec::Multicore::RunnerPatch
