# rspec_junit_formatter

Tested with rspec_junit_formatter 0.6.0, Ruby 3.4, and two workers. Serial and parallel reports contain the same passed, failed, and pending cases with valid counts, durations, and no duplicates.

## Installation

```ruby
group :test do
  gem "rspec_junit_formatter", "0.6.0", require: false
  gem "rspec-multicore"
end
```

## Project helper

Create `spec/support/rspec_multicore/junit.rb`:

```ruby
# frozen_string_literal: true

require "fileutils"
require "rspec_junit_formatter"
require "rspec/multicore"

report_path = File.expand_path("../../../tmp/rspec.xml", __dir__)
FileUtils.mkdir_p(File.dirname(report_path))

RSpec.configure do |config|
  config.add_formatter(RspecJunitFormatter, report_path)
end
```

## Load the helper

```ruby
# spec/spec_helper.rb
require_relative "support/rspec_multicore/junit"
```

No worker hook or per-worker XML file is needed. RSpec Multicore replays one ordered event stream through the parent reporter, so the formatter owns one `tmp/rspec.xml` report.

Do not configure another JUnit formatter per worker unless some separate test runner bypasses the parent reporter.

See the executable [JUnit fixture](../../compatibility/fixtures/junit/mixed_spec.rb).

