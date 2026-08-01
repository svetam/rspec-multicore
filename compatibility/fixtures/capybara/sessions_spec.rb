# frozen_string_literal: true

RSpec.describe "first Capybara session" do
  it "keeps its rack-test cookie local" do
    verify_session("first")
  end
end

RSpec.describe "second Capybara session" do
  it "keeps its rack-test cookie local" do
    verify_session("second")
  end
end

def verify_session(value)
  session = Capybara::Session.new(:rack_test, CAPYBARA_APP)
  session.visit("/set/#{value}")

  expect(session).to have_text("/#{value}:#{value}")
  CompatibilityEvidence.record(value:, slot: ENV.fetch("RSPEC_MULTICORE_WORKER", "serial"))
end
