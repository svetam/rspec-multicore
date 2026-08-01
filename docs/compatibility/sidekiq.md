# Sidekiq and Redis

Tested with Sidekiq 8.1.6, Redis, Ruby 3.4, and two workers. Workers use different Redis databases, queues cannot see one another, and shutdown removes temporary data and closes worker-owned pools.

## Installation

```ruby
group :test do
  gem "sidekiq", "8.1.6"
  gem "rspec-multicore"
end
```

Reserve a Redis server and database range exclusively for tests:

```bash
export TEST_REDIS_URL=redis://127.0.0.1:6379
```

Never point this setup at production or shared development data.

## Project helper

Create `spec/support/rspec_multicore/sidekiq.rb`:

```ruby
# frozen_string_literal: true

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

# Serial mode uses database 12. This configures the lazy pool without opening it.
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

## Load the helper

Require it before application setup can open Sidekiq’s Redis pool:

```ruby
# spec/spec_helper.rb
require_relative "support/rspec_multicore/sidekiq"
```

With two workers, databases 13 and 14 are used. Ensure the reserved range fits the Redis server’s configured database count and does not overlap another test process.

This tests Sidekiq client queues, not execution by external Sidekiq server processes. External workers need their own explicit resource mapping.

See the executable [Sidekiq fixture](../../compatibility/fixtures/sidekiq/spec_helper.rb).

