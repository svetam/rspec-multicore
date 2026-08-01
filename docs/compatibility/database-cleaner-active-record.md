# Database Cleaner ActiveRecord

Tested with database_cleaner-active_record 2.2.2, Ruby 3.4, Rails 8.0, and two workers. Transaction cleanup is performed through each worker's isolated ActiveRecord connection, and the compatibility test verifies that every worker database is empty after the examples finish.

## Installation

```ruby
group :test do
  gem "database_cleaner-active_record", "2.2.2", require: false
  gem "rspec-multicore-rails"
end
```

## Configuration

Require the Rails adapter before configuring Database Cleaner:

```ruby
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

No additional worker hook is required for the transaction strategy: the block runs inside the worker after the Rails adapter has established that worker's connection.

The compatibility matrix does not currently prove truncation or deletion strategies. If your suite uses them, ensure they operate only on disposable test databases prepared by `db:test:multicore:prepare` before adopting the configuration.

See the executable [Database Cleaner fixture](../../compatibility/fixtures/rails_stack/spec_helper.rb).

