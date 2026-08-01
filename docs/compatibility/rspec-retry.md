# rspec-retry

Tested with rspec-retry 0.6.2, Ruby 3.4, and two workers. A failing first attempt succeeds on retry, while the parent reporter receives one final successful example result with no duplicate events.

## Installation

```ruby
group :test do
  gem "rspec-retry", "0.6.2", require: false
  gem "rspec-multicore"
end
```

## Configuration

```ruby
require "rspec/retry"
require "rspec/multicore"

RSpec.configure do |config|
  config.verbose_retry = false
  config.default_retry_count = 2
end
```

Apply retry metadata using rspec-retry's ordinary interface:

```ruby
RSpec.describe ApiClient do
  it "handles an eventually available service", retry: 2 do
    expect(ApiClient.status).to eq(:available)
  end
end
```

No multicore hook is required. Retries happen entirely inside the worker executing that example group, and only its final RSpec result is replayed by the parent.

Retries can conceal nondeterministic tests; use targeted metadata when possible rather than enabling high retry counts globally. See the executable [rspec-retry fixture](../../compatibility/fixtures/rspec_retry/retry_spec.rb).

