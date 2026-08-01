# Capybara

Tested with Capybara 3.40.0, the rack-test driver, Ruby 3.4, and two workers. Independent sessions retain their own cookies, while final RSpec identities and statuses match the serial run.

## Installation

```ruby
group :test do
  gem "capybara", "3.40.0"
  gem "rspec-multicore"
end
```

## Configuration

```ruby
require "capybara/rspec"
require "rspec/multicore"

Capybara.default_driver = :rack_test
```

Use Capybara's ordinary RSpec integration. It resets the session around examples, and each worker owns its in-memory session state:

```ruby
RSpec.describe "account page", type: :feature do
  it "shows the signed-in account" do
    visit "/account"
    expect(page).to have_text("Account")
  end
end
```

No multicore lifecycle hook is required for rack-test. Avoid sharing custom `Capybara::Session` instances through files, sockets, or another external resource.

Selenium, browser processes, driver ports, downloads, and screenshot paths are not covered by this recipe. Those resources may need worker-specific configuration using `RSPEC_MULTICORE_WORKER`. See the executable [Capybara fixture](../../compatibility/fixtures/capybara/spec_helper.rb).

