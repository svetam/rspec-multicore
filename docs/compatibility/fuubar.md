# Fuubar

Tested with Fuubar 2.5.1, Ruby 3.4, and two workers. Fuubar receives the parent’s ordered reporter stream with the correct summary and no duplicated examples.

## Installation

```ruby
group :test do
  gem "fuubar", "2.5.1", require: false
  gem "rspec-multicore"
end
```

## Project helper

Create `spec/support/rspec_multicore/fuubar.rb`:

```ruby
# frozen_string_literal: true

require "fuubar"
require "rspec/multicore"

RSpec.configure do |config|
  config.add_formatter(Fuubar)
end
```

## Load the helper

```ruby
# spec/spec_helper.rb
require_relative "support/rspec_multicore/fuubar"
```

No worker hook or output collation is required. Fuubar consumes the standard parent reporter notifications just as it does during serial execution.

Custom formatters that invoke unsupported, nonstandard reporter methods remain outside this recipe.

See the executable [Fuubar fixture](../../compatibility/fixtures/fuubar/spec_helper.rb).

