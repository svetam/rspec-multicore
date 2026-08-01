# FactoryBot Rails

Tested with factory_bot_rails 6.5.1, Ruby 3.4, Rails 8.0, and two workers. Factories create records through each worker’s isolated ActiveRecord connection.

## Installation

```ruby
group :test do
  gem "factory_bot_rails", "6.5.1"
  gem "rspec-multicore-rails"
end
```

## Project helper

Create `spec/support/rspec_multicore/factory_bot.rb`:

```ruby
# frozen_string_literal: true

require "factory_bot_rails"
require "rspec/multicore/rails"

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
```

## Load the helper

Load it from `rails_helper.rb` after the Rails environment initializes:

```ruby
# spec/rails_helper.rb
require File.expand_path("../config/environment", __dir__)
require_relative "support/rspec_multicore/factory_bot"
```

No FactoryBot-specific worker hook is required. Factories and callbacks use the ActiveRecord connection selected by `rspec-multicore-rails`.

Prepare disposable worker databases before running:

```bash
bundle exec rake db:test:multicore:prepare
bundle exec rspec
```

Worker 1 uses the base test database and later workers use suffixed databases. Factory sequences are process-local, so database constraints should remain the source of truth for globally unique values.

See the executable [FactoryBot fixture](../../compatibility/fixtures/rails_stack/widgets_spec.rb).
