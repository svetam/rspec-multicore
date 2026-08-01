# VCR

Tested with VCR 6.4.0, WebMock 3.26.2, Ruby 3.4, and two workers. Both workers concurrently replay a committed cassette with no external request, cassette mutation, or cross-worker state leakage.

## Installation

```ruby
group :test do
  gem "vcr", "6.4.0", require: false
  gem "webmock", "3.26.2", require: false
  gem "rspec-multicore"
end
```

## Configuration

```ruby
require "vcr"
require "webmock/rspec"
require "rspec/multicore"

VCR.configure do |config|
  config.cassette_library_dir = "spec/cassettes"
  config.hook_into :webmock
  config.default_cassette_options = { record: :none }
  config.allow_http_connections_when_no_cassette = false
end

WebMock.disable_net_connect!
```

Use cassettes normally:

```ruby
VCR.use_cassette("account_lookup") do
  expect(ApiClient.fetch_account(42)).to include("id" => 42)
end
```

No multicore hook is required for read-only replay. Commit cassettes before the parallel run and use `record: :none` in CI.

Concurrent cassette recording and rewriting are not covered. Record or refresh cassettes in serial mode, review the changes, and then return the suite to read-only replay. See the executable [VCR fixture](../../compatibility/fixtures/http/spec_helper.rb).

