# frozen_string_literal: true

RSpec.describe "Pending examples" do
  it "is pending" do
    pending "Not implemented yet"
    expect(false).to be true
  end

  it "passes after pending" do
    expect(42).to eq(42)
  end

  xit "is skipped" do
    expect(false).to be true
  end
end
