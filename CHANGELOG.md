# Changelog

## 0.2.0.pre4 - 2026-08-19

### Fixed

- (#16) Handle SIGINT gracefully during parallel execution

## 0.2.0.pre3 - 2026-08-07

### Fixed

- (#11) Fix Rails database lifecycle and parallel coverage for pre3

## 0.2.0.pre2 - 2026-07-20

### Changed

- Reserve merges to `master` for validated releases prepared on `develop`.
- Make release publication independently retryable across RubyGems, Git tags,
  and GitHub Releases.
- Add focused maintainer tooling for retrying failed release workflow runs.
- Integrate worker test databases with Rails' standard create, prepare,
  schema-load, purge, and drop task lifecycle.
- Support every writable Rails test database configuration without duplicated
  worker entries in `database.yml`.

## 0.2.0.pre1 - 2026-07-18

First public prerelease.

### Added

- Persistent forked workers with dynamic top-level group assignment.
- `RSPEC_MULTICORE` automatic, explicit-count, and disabled forms.
- Configurable worker count plus fork and reverse-order shutdown hooks.
- RSpec-independent Channel and process Pool components.
- Parent object registry and bounded reporter-event snapshots.
- ActiveRecord database isolation and focused database tasks for Rails 7.1–8.x.

### Compatibility and behavior

- Supports Ruby 3.2+ and RSpec Core 3.13.x.
- Patches only `RSpec::Core::Runner#run_specs` and delegates suite ownership to
  native RSpec.
- Transfers stable IDs and plain state snapshots rather than RSpec/application
  objects.
- Supports standard RSpec 3.13 reporter events with seeded ordered replay.
- Uses native serial RSpec for fail-fast, dry-run, disabled mode, unsupported
  fork runtimes, and insufficient parallel work.
- Automatically integrates only ActiveRecord; other process-owned resources use
  explicit lifecycle hooks.
- Treats serial coverage as the safe default.
- Finishes workers with `exit!`; inherited `at_exit` callbacks do not run.
