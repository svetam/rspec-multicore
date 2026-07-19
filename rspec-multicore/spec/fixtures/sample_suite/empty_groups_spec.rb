# frozen_string_literal: true

RSpec.describe "Group with examples" do
  it "has one example" do
    expect(true).to be true
  end
end

RSpec.describe "Empty group" do
  # No examples here - intentionally empty
end

RSpec.describe "Another group with examples" do
  it "also has one example" do
    expect(1).to eq(1)
  end
end
