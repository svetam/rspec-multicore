# frozen_string_literal: true

RSpec.describe "passing JUnit group" do
  it("passes") { expect(1 + 1).to eq(2) }
end

RSpec.describe "failing JUnit group" do
  it("fails") { expect(1 + 1).to eq(3) }
end

RSpec.describe "pending JUnit group" do
  it "is pending" do
    pending "not implemented"
    raise "pending"
  end
end
