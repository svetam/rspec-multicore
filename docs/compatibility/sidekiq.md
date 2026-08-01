# Sidekiq and Redis

Tested with Sidekiq 8.1.6, Redis, Ruby 3.4, and two workers. Serial and parallel example results match; workers use different Redis databases; queues cannot see one another; and shutdown removes temporary data and closes each worker-owned pool.

## Installation

```ruby
group :test do
  gem "sidekiq", "8.1.6"
  gem "rspec-multicore"
end
```

Reserve a Redis server and database range exclusively for tests. Never point this configuration at production or shared development data.

```bash
export TEST_REDIS_URL=redis://127.0.0.1:6379
```

## Configuration

Add this to the test setup before any code opens Sidekiq's Redis pool:

```ruby
require "sidekiq"
require "rspec/multicore"

module TestSidekiqIsolation
  BASE_DATABASE = 12

  module_function

  def configure(slot)
    base_url = ENV.fetch("TEST_REDIS_URL").sub(%r{/\d+\z}, "")
    database = BASE_DATABASE + slot
    Sidekiq.configure_client { _1.redis = { url: "#{base_url}/#{database}" } }
  end

  def clear
    Sidekiq.redis { _1.call("FLUSHDB") }
  end

  def shutdown
    clear
    Sidekiq.redis_pool.shutdown(&:close)
  end
end

# Serial mode uses database 12. This only configures the lazy pool; do not
# connect to Redis in the parent before workers fork.
TestSidekiqIsolation.configure(0)

RSpec::Multicore.on_worker_fork do |slot|
  TestSidekiqIsolation.configure(slot)
  TestSidekiqIsolation.clear
end

RSpec::Multicore.on_worker_shutdown do
  TestSidekiqIsolation.shutdown
end

RSpec.configure do |config|
  config.before { TestSidekiqIsolation.clear }
  config.after { TestSidekiqIsolation.clear }
end
```

With two workers, the snippet uses Redis databases 13 and 14. Increase or relocate the range if another test process uses those databases. Redis commonly defaults to 16 databases, so ensure the configured worker count fits the server configuration.

This recipe tests Sidekiq client queue isolation, not execution by Sidekiq server processes. If the application starts external workers, their configuration must select the corresponding worker resource explicitly. See the executable [Sidekiq fixture](../../compatibility/fixtures/sidekiq/spec_helper.rb).

