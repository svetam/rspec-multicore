# Capybara

Tested with Capybara 3.40.0, the rack-test driver, Ruby 3.4, and two workers. Independent sessions retain their own cookies, while final RSpec identities and statuses match serial execution.

## Installation

```ruby
group :test do
  gem "capybara", "3.40.0"
  gem "rspec-multicore"
end
```

## Project helper

Create `spec/support/rspec_multicore/capybara.rb`:

```ruby
# frozen_string_literal: true

require "capybara/rspec"
require "rspec/multicore"

Capybara.default_driver = :rack_test
```

## Load the helper

```ruby
# spec/spec_helper.rb
require_relative "support/rspec_multicore/capybara"
```

Capybara’s RSpec integration resets sessions around examples, and each worker owns its in-memory rack-test state. No multicore hook is required for rack-test.

Selenium, browser processes, driver ports, downloads, and screenshot paths are not covered. Configure those external resources with worker-specific values when needed, using `RSPEC_MULTICORE_WORKER`.

See the executable [Capybara fixture](../../compatibility/fixtures/capybara/spec_helper.rb).

