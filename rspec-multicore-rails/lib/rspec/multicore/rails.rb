# frozen_string_literal: true

require "rspec/multicore"
require "rails"
require_relative "rails/version"
require_relative "rails/database_manager"

module RSpec
  module Multicore
    module Rails
      # Registers automatic ActiveRecord reconnection and database tasks.
      class Railtie < ::Rails::Railtie
        railtie_name :rspec_multicore_rails

        initializer "rspec_multicore_rails.active_record" do
          RSpec::Multicore.on_worker_fork do |slot|
            DatabaseManager.new.connect_worker(slot)
          end
        end

        rake_tasks do
          load File.expand_path("../../tasks/multicore.rake", __dir__)
        end
      end
    end
  end
end
