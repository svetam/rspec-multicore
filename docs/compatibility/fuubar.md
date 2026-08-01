# Fuubar

Tested with Fuubar 2.5.1, Ruby 3.4, and two workers. Serial and parallel identities and statuses match, and Fuubar receives the ordered parent reporter stream with the correct summary and no duplicated examples.

## Installation

```ruby
group :test do
  gem "fuubar", "2.5.1", require: false
  gem "rspec-multicore"
end
```

## Configuration

No worker hook or output collation is needed. Configure Fuubar as a normal parent-owned RSpec formatter:

```text
# .rspec
--require fuubar
--format Fuubar
```

Or invoke it directly:

```bash
bundle exec rspec --require fuubar --format Fuubar
```

RSpec Multicore buffers standard reporter events by top-level group and replays them in seeded order. Fuubar consumes that parent event stream just as it does during a serial run.

Custom formatters that call unsupported, nonstandard reporter methods are outside this recipe. See the executable [Fuubar fixture](../../compatibility/fixtures/fuubar/spec_helper.rb).

