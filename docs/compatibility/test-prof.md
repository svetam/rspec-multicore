# TestProf

Tested with TestProf 1.6.3 FactoryProf, Ruby 3.4, and two workers. Each worker collects profiler events and explicitly writes a distinct artifact during shutdown; neither worker depends on an inherited `at_exit` callback.

## Installation

```ruby
group :test do
  gem "test-prof", "1.6.3", require: false
  gem "rspec-multicore"
end
```

## Configuration

This copy-paste example creates one JSON summary per worker:

```ruby
require "json"
require "fileutils"
require "test_prof"
require "test_prof/factory_prof"
require "rspec/multicore"

profile_directory = File.expand_path("../tmp/test-prof", __dir__)
FileUtils.mkdir_p(profile_directory)

RSpec::Multicore.on_worker_fork do
  TestProf::FactoryProf.init
  TestProf::FactoryProf.start
end

RSpec::Multicore.on_worker_shutdown do |slot|
  TestProf::FactoryProf.stop
  result = TestProf::FactoryProf.result

  File.write(
    File.join(profile_directory, "factory-prof-worker-#{slot}.json"),
    JSON.pretty_generate(
      total_count: result.total_count,
      factories: result.stats.map { _1.fetch(:name) }
    )
  )
end
```

The important boundary is explicit worker finalization and a slot-specific path. A profiler that only writes from `at_exit` will lose its worker output because multicore workers finish with `exit!`.

This recipe proves FactoryProf's collection API and custom JSON artifacts. Other TestProf profilers and TestProf's own presentation formats may expose different finalization APIs and are not covered yet. See the executable [TestProf fixture](../../compatibility/fixtures/test_prof/spec_helper.rb).
