# VCR

Tested with VCR 6.4.0, WebMock 3.26.2, Ruby 3.4, and two workers. Both workers replay a committed cassette with no external request, cassette mutation, or shared request state.

## Installation

```ruby
group :test do
  gem "vcr", "6.4.0", require: false
  gem "webmock", "3.26.2", require: false
  gem "rspec-multicore"
end
```

## Project helper

Create `spec/support/rspec_multicore/vcr.rb`:

```ruby
# frozen_string_literal: true

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

## Load the helper

```ruby
# spec/spec_helper.rb
require_relative "support/rspec_multicore/vcr"
```

No multicore hook is required for read-only replay. Commit cassettes before parallel runs and keep `record: :none` in CI. Record or refresh cassettes in serial mode because concurrent recording and rewriting are not covered.

See the executable [VCR fixture](../../compatibility/fixtures/http/spec_helper.rb).

