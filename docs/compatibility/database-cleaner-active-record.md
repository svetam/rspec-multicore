# Database Cleaner ActiveRecord

Tested with database_cleaner-active_record 2.2.2, Ruby 3.4, Rails 8.0, and two workers. Transaction cleanup uses each worker’s isolated ActiveRecord connection, and every worker database is empty after the examples finish.

## Installation

```ruby
group :test do
  gem "database_cleaner-active_record", "2.2.2", require: false
  gem "rspec-multicore-rails"
end
```

## Project helper

Create `spec/support/rspec_multicore/database_cleaner.rb`:

```ruby
# frozen_string_literal: true

require "rspec/multicore/rails"
require "database_cleaner/active_record"

DatabaseCleaner[:active_record].strategy = :transaction

RSpec.configure do |config|
  config.around do |example|
    DatabaseCleaner[:active_record].cleaning do
      example.run
    end
  end
end
```

## Load the helper

Load it from `rails_helper.rb` after Rails initializes ActiveRecord:

```ruby
# spec/rails_helper.rb
require File.expand_path("../config/environment", __dir__)
require_relative "support/rspec_multicore/database_cleaner"
```

No additional worker hook is required for the transaction strategy because the cleaning block runs after the Rails adapter establishes the worker connection.

Truncation and deletion strategies are not covered. If the project uses them,
ensure they can only target disposable databases prepared with the standard
`bin/rails db:prepare` workflow.

See the executable [Database Cleaner fixture](../../compatibility/fixtures/rails_stack/spec_helper.rb).
