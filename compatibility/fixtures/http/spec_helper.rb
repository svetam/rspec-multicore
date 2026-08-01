# frozen_string_literal: true

require "vcr"
require "webmock/rspec"
require "rspec/multicore"

VCR.configure do |config|
  config.cassette_library_dir = File.join(ENV.fetch("HTTP_FIXTURE_ROOT"), "cassettes")
  config.hook_into :webmock
  config.default_cassette_options = { record: :none }
  config.allow_http_connections_when_no_cassette = false
end

WebMock.disable_net_connect!
