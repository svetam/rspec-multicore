# SimpleCov

Tested with SimpleCov 1.0.3, Ruby 3.4, and two RSpec Multicore workers. The compatibility test compares serial and parallel RSpec results, requires both workers to produce distinct result sets, collates those results, and generates an HTML report containing files covered exclusively by different workers.

## Installation

```ruby
group :test do
  gem "simplecov", "1.0.3", require: false
  gem "rspec-multicore"
end
```

## RSpec setup

SimpleCov must start before application code is loaded. Put this at the beginning of `spec/spec_helper.rb`, adjusting the profile and filters for your project:

```ruby
require "simplecov"

coverage_results = File.expand_path("../tmp/coverage", __dir__)

SimpleCov.start do
  coverage_dir File.join(coverage_results, "parent")
end

# Multicore workers use exit!, so the inherited at_exit finalizer cannot own
# worker coverage.
SimpleCov.at_exit {}

require "rspec/multicore"

RSpec::Multicore.on_worker_fork do |slot|
  SimpleCov.command_name("rspec-multicore-worker-#{slot}")
  SimpleCov.coverage_dir(File.join(coverage_results, "worker-#{slot}"))
end

RSpec::Multicore.on_worker_shutdown do
  SimpleCov.result.format!
end
```

If the project already uses a SimpleCov profile, filters, groups, or `track_files`, keep that configuration inside this `SimpleCov.start` block.

## Generate the combined HTML report

Create `script/collate_coverage.rb`:

```ruby
# frozen_string_literal: true

require "simplecov"

project_root = File.expand_path("..", __dir__)
resultsets = Dir[File.join(project_root, "tmp/coverage/worker-*/.resultset.json")]

abort "No worker coverage results found" if resultsets.empty?

SimpleCov.collate(resultsets) do
  root project_root
  coverage_dir File.join(project_root, "coverage")
  formatter SimpleCov::Formatter::HTMLFormatter
end
```

Run RSpec and then collate:

```bash
bundle exec rspec
bundle exec ruby script/collate_coverage.rb
open coverage/index.html
```

The final report is `coverage/index.html`. Configure CI to run the collation step even when RSpec fails if coverage from failing runs is required.

## Why this is necessary

Each process owns a partial coverage result. Unique command names and directories prevent workers from overwriting one another. The shutdown hook saves coverage before `exit!`, and `SimpleCov.collate` creates the union used by the final formatter.

This is application-owned configuration; RSpec Multicore does not automatically start or merge SimpleCov. See the executable [SimpleCov fixture](../../compatibility/fixtures/simplecov/spec_helper.rb).
