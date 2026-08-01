# Bullet

Tested with Bullet 8.1.3, ActiveRecord, Ruby 3.4, Rails 7.1 and 8.0, and two workers. Bullet's inherited ActiveSupport and ActiveRecord instrumentation detects an N+1 query independently in each worker, while serial and parallel RSpec results match.

## Installation

```ruby
group :test do
  gem "bullet", "8.1.3"
  gem "rspec-multicore-rails"
end
```

## Configuration

Load Bullet after ActiveRecord and enable the detectors needed by the project:

```ruby
require "rspec/multicore/rails"
require "bullet"

Bullet.enable = true
Bullet.n_plus_one_query_enable = true

RSpec.configure do |config|
  config.before do
    Bullet.start_request
  end

  config.after do
    if Bullet.notification?
      Bullet.perform_out_of_channel_notifications
    end
  ensure
    Bullet.end_request
  end
end
```

Configure Bullet's notifier or `Bullet.raise` according to the application's existing test policy. RSpec Multicore does not replace that policy; it preserves the instrumented process state inherited by each worker.

No multicore hook is required when Bullet is initialized before the fork and all query work occurs inside examples. Notification targets that write files or use shared external resources may require worker-specific paths of their own.

See the executable [Bullet fixture](../../compatibility/fixtures/bullet/spec_helper.rb).

