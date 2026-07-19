# frozen_string_literal: true

module SpecHelpers
  def build_user(name:) = { name: name, created_at: Time.now }

  def format_name(user) = user[:name].upcase
end

RSpec.describe "Helper methods" do
  include SpecHelpers

  let(:user) { build_user(name: "alice") }

  it "uses helper to build" do
    expect(user[:name]).to eq("alice")
  end

  it "uses helper to format" do
    expect(format_name(user)).to eq("ALICE")
  end

  describe "in nested context" do
    let(:another_user) { build_user(name: "bob") }

    it "helpers available in nested" do
      expect(format_name(another_user)).to eq("BOB")
    end
  end
end

RSpec.describe "Another group with helpers" do
  include SpecHelpers

  it "also has access" do
    user = build_user(name: "charlie")
    expect(user[:name]).to eq("charlie")
  end
end
