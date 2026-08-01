# frozen_string_literal: true

require "sidekiq"
require "sidekiq/api"
require "rspec/multicore"
require_relative "../support"

module CompatibilitySidekiq
  module_function

  def configure(slot)
    database = 12 + slot
    url = "#{ENV.fetch("REDIS_URL").sub(%r{/\d+\z}, "")}/#{database}"
    Sidekiq.configure_client { _1.redis = { url: } }
    ENV["COMPATIBILITY_REDIS_DATABASE"] = database.to_s
  end

  def cleanup
    Sidekiq.redis { _1.call("FLUSHDB") }
    Sidekiq.redis_pool.shutdown(&:close)
  end
end

CompatibilitySidekiq.configure(0)
RSpec::Multicore.on_worker_fork { CompatibilitySidekiq.configure(_1) }
RSpec::Multicore.on_worker_shutdown { CompatibilitySidekiq.cleanup }

class CompatibilityJob
  include Sidekiq::Job
end

RSpec.configure do |config|
  config.before { Sidekiq.redis { _1.call("FLUSHDB") } }
  config.after { Sidekiq.redis { _1.call("FLUSHDB") } }
end
