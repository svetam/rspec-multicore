# FactoryBot Rails

Tested with factory_bot_rails 6.5.1, Ruby 3.4, Rails 8.0, and two workers. Factories create records through each worker's ActiveRecord connection and isolated test database.

## Installation

```ruby
group :test do
  gem "factory_bot_rails", "6.5.1"
  gem "rspec-multicore-rails"
end
```

Load the Rails adapter from your test setup:

```ruby
require "rspec/multicore/rails"
```

## Configuration

FactoryBot requires no multicore-specific hook. Existing factories and callbacks use the ActiveRecord connection selected by `rspec-multicore-rails`:

```ruby
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
```

Example:

```ruby
RSpec.describe Account do
  it "creates an account in the current worker database" do
    account = create(:account)
    expect(Account.where(id: account.id)).to exist
  end
end
```

Prepare the disposable worker databases before running the suite:

```bash
bundle exec rake db:test:multicore:prepare
bundle exec rspec
```

Worker 1 uses the base test database; later workers use suffixed databases. Factory sequences are process-local, so database uniqueness constraints should remain the source of truth when tests depend on globally unique values.

See the executable [FactoryBot fixture](../../compatibility/fixtures/rails_stack/widgets_spec.rb).
