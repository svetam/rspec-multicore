# rspec-retry

Tested with rspec-retry 0.6.2, Ruby 3.4, and two workers. A failing first attempt succeeds on retry, and the parent receives one final successful result without duplicated events.

## Installation

```ruby
group :test do
  gem "rspec-retry", "0.6.2", require: false
  gem "rspec-multicore"
end
```

## Project helper

Create `spec/support/rspec_multicore/rspec_retry.rb`:

```ruby
# frozen_string_literal: true

require "rspec/retry"
require "rspec/multicore"

RSpec.configure do |config|
  config.verbose_retry = false
  config.default_retry_count = 2
end
```

## Load the helper

```ruby
# spec/spec_helper.rb
require_relative "support/rspec_multicore/rspec_retry"
```

Use ordinary retry metadata:

```ruby
it "handles an eventually available service", retry: 2 do
  expect(ApiClient.status).to eq(:available)
end
```

Retries happen inside the worker executing the example group, so no multicore hook is required. Prefer targeted metadata because broad retry policies can conceal nondeterministic tests.

See the executable [rspec-retry fixture](../../compatibility/fixtures/rspec_retry/retry_spec.rb).

