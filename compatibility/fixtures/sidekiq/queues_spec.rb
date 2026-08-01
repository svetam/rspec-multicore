# frozen_string_literal: true

RSpec.describe "first Sidekiq queue" do
  it "uses only its worker Redis database" do
    verify_queue("first")
  end
end

RSpec.describe "second Sidekiq queue" do
  it "uses only its worker Redis database" do
    verify_queue("second")
  end
end

def verify_queue(name)
  CompatibilityJob.set(queue: name).perform_async(name)

  expect(Sidekiq::Queue.new(name).size).to eq(1)
  expect(Sidekiq::Queue.new(name == "first" ? "second" : "first").size).to eq(0)
  CompatibilityEvidence.record(
    database: ENV.fetch("COMPATIBILITY_REDIS_DATABASE"),
    queue: name,
    slot: ENV.fetch("RSPEC_MULTICORE_WORKER", "serial")
  )
end
