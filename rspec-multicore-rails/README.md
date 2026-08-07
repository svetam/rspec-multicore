# rspec-multicore-rails

`rspec-multicore-rails` loads `rspec-multicore` and automatically isolates ActiveRecord connections for Rails test workers.

## Installation

```ruby
group :test do
  gem "rspec-multicore-rails", "0.2.0.pre3"
end
```

Normal `Bundler.require` loading requires no `require: false`, initializer, or
manual require. The adapter loads the matching core gem automatically.

Worker 1 uses the base test database. Later workers use `_2`, `_3`, and so on;
SQLite suffixes are placed before the extension. The adapter refuses to connect
workers outside test and clears inherited connections before connecting.

Use Rails' standard database tasks to manage the base and worker databases:

```bash
bin/rails db:prepare
bin/rails db:test:prepare
bin/rails db:reset
```

Create, schema-load, prepare, purge, and drop operations extend to the extra
worker databases whenever the Rails task includes test. Multiple writable test
configurations are supported; replicas and configurations with
`database_tasks: false` are not managed. No worker entries are needed in
`database.yml`, and running RSpec never mutates the database lifecycle.

The adapter does not manage Redis, Sidekiq, caches, loggers, SimpleCov, or profilers. Configure those with `RSpec::Multicore.on_worker_fork` and `on_worker_shutdown`.

Requires Ruby 3.2+, Rails/ActiveRecord 7.1–8.x, and exactly the matching `rspec-multicore` version.
