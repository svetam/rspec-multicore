# frozen_string_literal: true

RSpec.describe "first Fuubar group" do
  it("reports success") { record_fuubar("first") }
end

RSpec.describe "second Fuubar group" do
  it("reports success") { record_fuubar("second") }
end

def record_fuubar(name)
  CompatibilityEvidence.record(name:, slot: ENV.fetch("RSPEC_MULTICORE_WORKER", "serial"))
  expect(name).to be_a(String)
end
