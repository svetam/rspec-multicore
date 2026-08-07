# frozen_string_literal: true

require "capybara/rspec"
require "rspec/multicore"
require_relative "../support"

CAPYBARA_APP = lambda do |env|
  request = Rack::Request.new(env)
  if request.path.start_with?("/set/")
    value = request.path.delete_prefix("/set/")
    return [302, { "location" => "/#{value}", "set-cookie" => "compatibility_session=#{value}; Path=/" }, []]
  end

  session = request.cookies.fetch("compatibility_session", "unset")
  [200, { "content-type" => "text/plain" }, ["#{request.path}:#{session}"]]
end
