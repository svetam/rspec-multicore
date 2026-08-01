# WebMock

Tested with WebMock 3.26.2, Ruby 3.4, and two workers. Stubs and request counts remain process-local, real network access is disabled, and unmet expectations produce the same RSpec failure in serial and parallel runs.

## Installation

```ruby
group :test do
  gem "webmock", "3.26.2", require: false
  gem "rspec-multicore"
end
```

## Project helper

Create `spec/support/rspec_multicore/webmock.rb`:

```ruby
# frozen_string_literal: true

require "webmock/rspec"
require "rspec/multicore"

WebMock.disable_net_connect!
```

## Load the helper

```ruby
# spec/spec_helper.rb
require_relative "support/rspec_multicore/webmock"
```

Use ordinary per-example stubs and expectations:

```ruby
request = stub_request(:get, "https://api.example.test/value")
  .to_return(status: 200, body: "ok")

expect(Net::HTTP.get(URI("https://api.example.test/value"))).to eq("ok")
expect(request).to have_been_requested.once
```

No lifecycle hook is required. Configuration loaded before the fork is inherited, while recorded requests belong to the worker that made them. Keep real network access disabled to avoid nondeterministic cross-worker behavior.

See the executable [WebMock fixture](../../compatibility/fixtures/http/http_spec.rb).

