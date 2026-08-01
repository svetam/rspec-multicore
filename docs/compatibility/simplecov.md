# SimpleCov

Tested with SimpleCov 1.0.3, Ruby 3.4, and two RSpec Multicore workers. Serial and parallel RSpec results match, both workers retain their exclusive coverage, and one `bundle exec rspec` run produces the combined HTML report.

## Installation

```ruby
group :test do
  gem "simplecov", "1.0.3", require: false
  gem "rspec-multicore"
end
```

## Project helper

Create `spec/support/rspec_multicore/simplecov.rb`:

```ruby
# frozen_string_literal: true

require "fileutils"
require "simplecov"

project_root = File.expand_path("../../..", __dir__)
worker_results = File.join(project_root, "tmp/rspec-multicore-coverage")

# Remove result sets from the previous run before workers fork.
FileUtils.rm_rf(worker_results)

SimpleCov.start do
  root project_root
  coverage_dir File.join(project_root, "coverage")

  # Keep the project's existing filters, groups, track_files, and thresholds.
end

require "rspec/multicore"

RSpec::Multicore.on_worker_fork do |slot|
  SimpleCov.command_name("rspec-multicore-worker-#{slot}")
  SimpleCov.coverage_dir(File.join(worker_results, "worker-#{slot}"))
  SimpleCov.formatter false
end

RSpec::Multicore.on_worker_shutdown do
  # Calling result stores this worker's .resultset.json. Formatting is
  # disabled in workers because the parent owns the final HTML report.
  SimpleCov.result.format!
end

RSpec.configure do |config|
  config.after(:suite) do
    resultsets = Dir[File.join(worker_results, "worker-*", ".resultset.json")]
    next if resultsets.empty? # Native serial RSpec keeps SimpleCov's normal at_exit.

    SimpleCov.collate(resultsets) do
      root project_root
      coverage_dir File.join(project_root, "coverage")
      formatter SimpleCov::Formatter::HTMLFormatter
    end

    # SimpleCov.collate already finalized the merged result.
    SimpleCov.at_exit {}
  end
end
```

## Load the helper

Require it at the very beginning of `spec/spec_helper.rb`, before Rails, the application, or any project source files:

```ruby
# spec/spec_helper.rb
require_relative "support/rspec_multicore/simplecov"

# Remaining test setup follows.
```

Run the suite normally:

```bash
bundle exec rspec
open coverage/index.html
```

When multicore runs, worker shutdown hooks save partial results and the parent `after(:suite)` hook collates them. If RSpec selects serial execution, no worker result sets exist and SimpleCov’s normal finalizer generates the report instead.

For coverage assembled across separate CI jobs or machines, use a standalone final job calling `SimpleCov.collate` on the downloaded result sets. That is an alternative to this single-process parent hook, not an additional command required for normal RSpec runs.

This helper is project-owned configuration; RSpec Multicore does not automatically start or merge SimpleCov. See the executable [SimpleCov fixture](../../compatibility/fixtures/simplecov/spec_helper.rb).
