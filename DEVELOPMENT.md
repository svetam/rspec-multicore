# Development Guide

RSpec::Multicore is a two-gem monorepo:

- `rspec-multicore` provides the RSpec 3.13 process runner.
- `rspec-multicore-rails` adds ActiveRecord database isolation for Rails
  7.1–8.x.

Both gems require Ruby 3.2+ and a POSIX runtime with `fork` and
`UNIXSocket.pair`.

## Architecture

The parent process loads the suite once. RSpec passes its top-level groups to a
small wrapper, which runs those groups in persistent forked workers and returns
their Boolean results in input order.

```text
RSpec::Core::Runner#run_specs
  -> ParallelGroups wrapper
    -> Pool
      -> worker Channel endpoints
      -> top-level ExampleGroup.run
      -> standard reporter events and snapshots
    -> parent ReporterBridge replay
  -> native RSpec summary and exit calculation
```

### RSpec integration

`RunnerPatch` is the only RSpec method override. It prepends
`RSpec::Core::Runner#run_specs`, wraps the selected top-level groups, and calls
`super`. RSpec continues to own suite hooks, reporter start/stop, summaries,
status persistence, and exit-code calculation.

The wrapper implements only the `each` and `map` behavior used by RSpec 3.13.
It delegates to native serial execution when multicore is disabled, `fork` is
unavailable, fewer than two groups or workers exist, or fail-fast/dry-run is
active.

### Channel

`Channel.pair` creates parent and worker endpoints from `UNIXSocket.pair`.
Frames have a length prefix and a bounded Marshal payload. Recursive validation
allows only arrays, hashes, symbols, strings, numbers, booleans, and `nil`.

A mutex covers each complete frame write, so application-created threads cannot
interleave frames. Reads handle partial input, EOF, corrupt payloads, and frame
size violations explicitly. The Channel has no RSpec or application-object
knowledge.

### Pool

The Pool owns process creation, dynamic assignment, worker state, lifecycle
hooks, cleanup, explicit PID reaping, and ordered Boolean results. Persistent
workers request another top-level group after completing their current group.

Worker fork hooks run in registration order. Shutdown hooks run in reverse
order, and every shutdown hook is attempted. Hook failures, worker exceptions,
disconnects, and abnormal exits make the run unsuccessful. Workers close their
resources and call `exit!`, so inherited `at_exit` callbacks do not run.

The Pool does not replace RSpec's parent signal handlers and does not detach
children.

### Parent registry and reporter bridge

Before forking, the parent registry indexes every selected top-level group,
nested descendant group, and example by its stable RSpec ID. Original objects
remain in the parent and never cross the Channel.

Workers emit a bounded set of standard RSpec 3.13 reporter events. Payloads use
group/example IDs plus small execution-result and exception snapshots. Exception
snapshots preserve the original class name, message, backtrace, cause, and
aggregate children when present.

Parent replay resolves the original object, updates only runtime description and
execution-result fields, and invokes the real reporter. Events are buffered per
top-level group and replayed in seeded input order. Unsupported reporter calls
raise `UnsupportedReporterEvent`; they never extend the serializer.

### Rails adapter

The Rails adapter automatically handles only ActiveRecord. It rejects non-test
environments, clears inherited connections, assigns worker 1 to the base test
database, and assigns later workers to suffixed databases. SQLite suffixes are
placed before the filename extension.

Redis, Sidekiq, caches, loggers, coverage tools, and profilers stay in the
application and use the public worker lifecycle hooks.

## Setup

Install dependencies independently for each gem:

```bash
cd rspec-multicore
bundle install

cd ../rspec-multicore-rails
bundle install
```

## Tests and lint

Run the complete suites:

```bash
cd rspec-multicore
bundle exec rake spec
bundle exec rubocop --cache false

cd ../rspec-multicore-rails
bundle exec rake spec
bundle exec rubocop --cache false
```

Run the minimum RSpec contract:

```bash
cd rspec-multicore
RSPEC_CORE_VERSION=3.13.0 bundle update rspec-core
RSPEC_CORE_VERSION=3.13.0 bundle exec rake spec
```

Run a Rails compatibility contract:

```bash
cd rspec-multicore-rails
RAILS_VERSION='~> 7.1' bundle update activerecord railties
RAILS_VERSION='~> 7.1' bundle exec rake spec
```

Run the required third-party compatibility tier:

```bash
cd compatibility/required
bundle install
bundle exec rake spec
```

Run the extended tier with Redis available:

```bash
cd compatibility/extended
bundle install
REDIS_URL=redis://127.0.0.1:6379 bundle exec rake spec
```

To exercise its Rails 7.1 contract, set `RAILS_VERSION='~> 7.1.0'` and update `activerecord` and `railties` before running. Restore the extended lockfile afterward. CI runs this tier weekly and on manual dispatch; it is intentionally outside the pull-request aggregate gate.

Restore the committed `Gemfile.lock` with `git restore Gemfile.lock` after a
local contract run. CI covers Ruby 3.2–3.4 on Ubuntu/macOS, minimum/latest RSpec
3.13, Rails 7.1/8.0, and the required compatibility tier.

## Debugging

Use native serial RSpec to isolate framework behavior:

```bash
RSPEC_MULTICORE=0 bundle exec rspec path/to/spec.rb
```

Use an explicit small worker count when investigating process behavior:

```bash
RSPEC_MULTICORE=2 bundle exec rspec path/to/specs
```

Prefer isolated Channel, Pool, snapshot, or database-manager examples before
adding output to the runtime. Worker debugging must account for `exit!` and the
absence of inherited `at_exit` callbacks.

## Design constraints

- Keep `Runner#run_specs` as the sole RSpec override.
- Do not copy RSpec runner internals.
- Do not send arbitrary objects through Channel.
- Support only standard reporter events required by RSpec 3.13.
- Keep process communication and scheduling independently testable.
- Keep Rails automation limited to ActiveRecord.
- Prefer serial fallback when parallel semantics are unsafe.
- Add project-specific integrations through lifecycle hooks.

See [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) for release verification and
[CONTRIBUTING.md](CONTRIBUTING.md) for contribution expectations.
