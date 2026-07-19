# rspec-multicore-rails

`rspec-multicore-rails` loads `rspec-multicore` and automatically isolates ActiveRecord connections for Rails test workers.

Worker 1 uses the base test database. Later workers use `_2`, `_3`, and so on; SQLite suffixes are placed before the extension. The adapter refuses non-test environments and clears inherited connections before connecting.

```bash
bundle exec rake db:test:multicore:prepare
bundle exec rake db:test:multicore:drop
bundle exec rake db:test:multicore:recreate
```

The adapter does not manage Redis, Sidekiq, caches, loggers, SimpleCov, or profilers. Configure those with `RSpec::Multicore.on_worker_fork` and `on_worker_shutdown`.

Requires Ruby 3.2+, Rails/ActiveRecord 7.1–8.x, and exactly the matching `rspec-multicore` version.
