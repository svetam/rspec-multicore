# frozen_string_literal: true

# Integration test to verify the runner seam works correctly
RSpec.describe "Runner Integration" do
  it "verifies runner patch is installed" do
    expect(RSpec::Core::Runner.ancestors).to include(RSpec::Multicore::RunnerPatch)
  end

  it "verifies ParallelGroups can be instantiated" do
    config = RSpec::Core::Configuration.new
    groups = []

    parallel_groups = RSpec::Multicore::ParallelGroups.new(groups, config)

    expect(parallel_groups).to be_a(RSpec::Multicore::ParallelGroups)
  end

  it "verifies Pool can be instantiated with reporter" do
    config = RSpec::Core::Configuration.new
    reporter = RSpec::Core::Reporter.new(config)

    pool = RSpec::Multicore::Pool.new(reporter:, configuration: config, workers: 2)

    expect(pool).to be_a(RSpec::Multicore::Pool)
    expect(pool.workers).to be_empty
  end

  it "keeps reporter ownership in RSpec" do
    config = RSpec::Core::Configuration.new

    parallel_groups = RSpec::Multicore::ParallelGroups.new([], config)

    expect(config.reporter).to be_a(RSpec::Core::Reporter)
    expect(parallel_groups).to be_a(Enumerable)
  end
end
