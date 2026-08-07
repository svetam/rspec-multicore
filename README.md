# RSpec::Multicore

RSpec::Multicore runs top-level RSpec example groups in persistent forked workers. The application and specs load once in the parent; workers request groups dynamically; the parent replays their standard RSpec events in seeded group order.

This repository contains:

- `rspec-multicore`, the RSpec 3.13 process runner.
- `rspec-multicore-rails`, the optional ActiveRecord database adapter for Rails 7.1–8.x.

Both gems require Ruby 3.2+ and a platform with `fork` and `UNIXSocket.pair`.

## Installation

```ruby
group :test do
  gem "rspec-multicore", "0.2.0.pre2"

  # Rails applications that use ActiveRecord:
  gem "rspec-multicore-rails", "0.2.0.pre2"
end
```

Require the core from your test setup. Rails applications can require the adapter instead; it loads the core automatically.

```ruby
require "rspec/multicore"
# or
require "rspec/multicore/rails"
```

## Worker count

`RSPEC_MULTICORE` is the only user-facing environment setting:

```bash
# Configured count or detected CPU count
bundle exec rspec
RSPEC_MULTICORE=auto bundle exec rspec

# Explicit count
RSPEC_MULTICORE=8 bundle exec rspec

# Native serial RSpec
RSPEC_MULTICORE=0 bundle exec rspec
RSPEC_MULTICORE=false bundle exec rspec
RSPEC_MULTICORE=off bundle exec rspec
```

Unset, `true`, `on`, and `auto` enable automatic selection. A positive integer selects that many workers. Unknown and negative values raise `ArgumentError`.

Ruby configuration is used when the environment does not provide an explicit count:

```ruby
RSpec::Multicore.configure do |config|
  config.workers = 8
end
```

`RSPEC_MULTICORE_WORKER` is set to the worker's stable, one-based slot.

## Process lifecycle hooks

Core has no application-specific resource handling. Use hooks for Redis, caches, profilers, coverage tools, or other process-owned state:

```ruby
RSpec::Multicore.on_worker_fork do |slot|
  Redis.current.close
  SomeProfiler.output_file = "tmp/profile-#{slot}.json"
end

RSpec::Multicore.on_worker_shutdown do |slot|
  SomeProfiler.finish(slot)
end
```

Fork hooks run in registration order. Shutdown hooks run in reverse order; all shutdown hooks are attempted, and any failure makes the suite unsuccessful. Workers finish with `exit!`, so inherited `at_exit` callbacks do not run. Finalize worker-owned output in a shutdown hook.

## Rails and ActiveRecord

The Rails adapter automatically handles only ActiveRecord:

- It refuses to connect workers outside `Rails.env.test?`.
- Worker 1 uses the base test database.
- Later workers use `_2`, `_3`, and so on. SQLite suffixes are inserted before the extension.
- Inherited connections are cleared before each worker establishes its own connection.
- Every writable test configuration managed by Rails database tasks gets a
  worker database. Replicas and configurations with `database_tasks: false`
  are not created, purged, or dropped.

Use the same database tasks as any Rails application. When the Rails task
includes the test environment, the adapter applies the corresponding create,
prepare, schema-load, purge, or drop operation to the extra worker databases:

```bash
bin/rails db:prepare
bin/rails db:test:prepare
bin/rails db:reset
```

No worker entries are needed in `database.yml`. Running RSpec never creates,
purges, or migrates databases; prepare them explicitly with Rails. The normal
test schema must be current, and the database user needs the privileges required
by the Rails task you invoke.

Redis, Sidekiq, cache stores, loggers, SimpleCov, and profilers are deliberately not automatic. Configure them with the lifecycle hooks when the project needs them.

## RSpec boundary

The integration patches only `RSpec::Core::Runner#run_specs` and delegates the suite lifecycle, hooks, summary, reporter start/stop, and exit-code calculation back to RSpec.

Parallel execution is skipped for disabled mode, unavailable `fork`, fewer than two groups or workers, fail-fast, and dry-run. These paths use native serial RSpec.

Workers never send RSpec or application objects to the parent. The parent keeps its original group and example objects in an ID registry. Workers send stable IDs and small execution-result or exception snapshots. The parent updates the original example's runtime description and execution result, then calls the real reporter with the original object.

Only these RSpec 3.13 reporter events are supported:

- `example_group_started`, `example_group_finished`
- `example_started`, `example_finished`
- `example_passed`, `example_failed`, `example_pending`
- `message`, `deprecation`, `notify_non_example_exception`

An unsupported reporter call fails explicitly; it does not expand the serializer. Custom formatters remain compatible when they consume RSpec's standard notifications. Events are buffered per top-level group and replayed in seeded order.

## Coverage

Serial coverage is the safe default:

```bash
RSPEC_MULTICORE=0 bundle exec rspec
```

RSpec::Multicore does not promise automatic SimpleCov merging. Parallel coverage requires project-owned worker names, result files, shutdown finalization, and merging configured through the lifecycle hooks.

## Tested compatibility recipes

These application-owned configurations are exercised by the compatibility test matrix. They are not built-in integrations or guarantees for every third-party version.

Required on pull requests:

- [SimpleCov](docs/compatibility/simplecov.md)
- [rspec_junit_formatter](docs/compatibility/rspec-junit-formatter.md)
- [FactoryBot Rails](docs/compatibility/factory-bot-rails.md)
- [Database Cleaner ActiveRecord](docs/compatibility/database-cleaner-active-record.md)
- [WebMock](docs/compatibility/webmock.md)
- [VCR](docs/compatibility/vcr.md)

Tested weekly and manually:

- [Capybara](docs/compatibility/capybara.md)
- [Sidekiq and Redis](docs/compatibility/sidekiq.md)
- [TestProf](docs/compatibility/test-prof.md)
- [rspec-retry](docs/compatibility/rspec-retry.md)
- [Fuubar](docs/compatibility/fuubar.md)
- [Bullet](docs/compatibility/bullet.md)

## Development

Run each gem independently:

```bash
cd rspec-multicore
bundle exec rake spec
bundle exec rubocop --cache false

cd ../rspec-multicore-rails
bundle exec rake spec
bundle exec rubocop --cache false

cd ../compatibility/required
bundle exec rake spec
```

See the [development guide](DEVELOPMENT.md), [contribution guide](CONTRIBUTING.md),
and [changelog](CHANGELOG.md). The project is licensed under the
[MIT License](LICENSE.txt).
