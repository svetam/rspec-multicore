# frozen_string_literal: true

require "json"
require "test_prof"
require "test_prof/factory_prof"
require "rspec/multicore"

RSpec::Multicore.on_worker_fork do
  TestProf::FactoryProf.init
  TestProf::FactoryProf.start
end

RSpec::Multicore.on_worker_shutdown do |slot|
  TestProf::FactoryProf.stop
  result = TestProf::FactoryProf.result
  File.write(
    File.join(ENV.fetch("PROFILE_DIRECTORY"), "worker-#{slot}.json"),
    JSON.generate(total_count: result.total_count, factories: result.stats.map { _1.fetch(:name) })
  )
end
