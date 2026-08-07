# TestProf

Tested with TestProf 1.6.3 FactoryProf, Ruby 3.4, and two workers. Each worker explicitly finalizes a distinct profiler artifact instead of relying on an inherited `at_exit` callback.

## Installation

```ruby
group :test do
  gem "test-prof", "1.6.3", require: false
  gem "rspec-multicore"
end
```

## Project helper

Create `spec/support/rspec_multicore/test_prof.rb`:

```ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "test_prof"
require "test_prof/factory_prof"
require "rspec/multicore"

profile_directory = File.expand_path("../../../tmp/test-prof", __dir__)
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

## Load the helper

```ruby
# spec/spec_helper.rb
require_relative "support/rspec_multicore/test_prof"
```

The essential boundary is explicit finalization and a slot-specific output path because multicore workers finish with `exit!`. This recipe covers FactoryProf’s collection API and custom JSON summaries; other TestProf profilers may require different finalization APIs.

See the executable [TestProf fixture](../../compatibility/fixtures/test_prof/spec_helper.rb).
