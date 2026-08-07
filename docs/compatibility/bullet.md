# Bullet

Tested with Bullet 8.1.3, ActiveRecord, Ruby 3.4, Rails 7.1 and 8.0, and two workers. Bullet’s inherited instrumentation detects an N+1 query independently in each worker.

## Installation

```ruby
group :test do
  gem "bullet", "8.1.3"
  gem "rspec-multicore-rails"
end
```

## Project helper

Create `spec/support/rspec_multicore/bullet.rb`:

```ruby
# frozen_string_literal: true

require "rspec/multicore/rails"
require "bullet"

Bullet.enable = true
Bullet.n_plus_one_query_enable = true

RSpec.configure do |config|
  config.before do
    Bullet.start_request
  end

  config.after do
    Bullet.perform_out_of_channel_notifications if Bullet.notification?
  ensure
    Bullet.end_request
  end
end
```

## Load the helper

Load it from `rails_helper.rb` after Rails and ActiveRecord initialize:

```ruby
# spec/rails_helper.rb
require File.expand_path("../config/environment", __dir__)
require_relative "support/rspec_multicore/bullet"
```

Configure Bullet’s notifier or `Bullet.raise` according to the project’s existing policy. No multicore hook is required when Bullet initializes before the fork and queries occur inside examples. File-based or external notification targets may need worker-specific resources.

See the executable [Bullet fixture](../../compatibility/fixtures/bullet/spec_helper.rb).

