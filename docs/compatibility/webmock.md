# WebMock

Tested with WebMock 3.26.2, Ruby 3.4, and two workers. The compatibility test proves stubs and request counts remain process-local, real network access is disabled, and an unmet request expectation produces the same normal RSpec failure in serial and parallel runs.

## Installation

```ruby
group :test do
  gem "webmock", "3.26.2", require: false
  gem "rspec-multicore"
end
```

## Configuration

```ruby
require "webmock/rspec"
require "rspec/multicore"

WebMock.disable_net_connect!
```

Use ordinary per-example stubs and expectations:

```ruby
RSpec.describe ApiClient do
  it "requests the configured endpoint once" do
    request = stub_request(:get, "https://api.example.test/value")
      .to_return(status: 200, body: "ok")

    expect(Net::HTTP.get(URI("https://api.example.test/value"))).to eq("ok")
    expect(request).to have_been_requested.once
  end
end
```

No lifecycle hook is required. A stub created before workers fork is inherited as configuration, while requests recorded afterward belong to the worker process that made them.

Keep real network access disabled in tests to avoid nondeterministic behavior across workers. See the executable [WebMock fixture](../../compatibility/fixtures/http/http_spec.rb).

