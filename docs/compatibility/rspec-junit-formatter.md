# rspec_junit_formatter

Tested with rspec_junit_formatter 0.6.0, Ruby 3.4, and two workers. The compatibility test compares serial and parallel pass, failure, and pending results; parses the XML; validates counts and durations; and rejects duplicate test cases.

## Installation

```ruby
group :test do
  gem "rspec_junit_formatter", "0.6.0", require: false
  gem "rspec-multicore"
end
```

## Configuration

No worker hook or per-worker XML file is needed. Configure one formatter in the parent:

```bash
bundle exec rspec \
  --require rspec_junit_formatter \
  --format RspecJunitFormatter \
  --out tmp/rspec.xml
```

Or put the equivalent in `.rspec`:

```text
--require rspec_junit_formatter
--format RspecJunitFormatter
--out tmp/rspec.xml
```

RSpec Multicore replays standard example notifications through the parent reporter in seeded order. The JUnit formatter therefore sees one normal RSpec event stream and owns one report.

Do not configure a formatter file per worker unless another part of your test setup bypasses the parent reporter. See the executable [JUnit fixture](../../compatibility/fixtures/junit/mixed_spec.rb).

