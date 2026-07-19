# frozen_string_literal: true

RSpec.describe "Single example group" do
  it "is the only example" do
    expect("single").to eq("single")
  end
end
