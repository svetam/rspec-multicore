# frozen_string_literal: true

RSpec.describe "first Bullet group" do
  it("detects an N+1 query") { verify_bullet("first") }
end

RSpec.describe "second Bullet group" do
  it("detects another N+1 query") { verify_bullet("second") }
end

def verify_bullet(name)
  Bullet.end_request
  2.times do |index|
    author = CompatibilityAuthor.create!(name: "#{name}-#{index}")
    CompatibilityBook.create!(author:, title: "book-#{index}")
  end
  Bullet.start_request

  CompatibilityAuthor.where("name LIKE ?", "#{name}-%").to_a.each { _1.books.to_a }
  expect(Bullet.notification?).to be(true)
  CompatibilityEvidence.record(name:, slot: ENV.fetch("RSPEC_MULTICORE_WORKER", "serial"))
ensure
  CompatibilityBook.delete_all
  CompatibilityAuthor.delete_all
end
