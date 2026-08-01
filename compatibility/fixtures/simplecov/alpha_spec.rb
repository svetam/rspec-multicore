# frozen_string_literal: true

RSpec.describe "alpha coverage" do
  it "loads code assigned to the first group" do
    require_relative "lib/alpha"
    expect(CoverageAlpha.call).to eq(:alpha)
  end
end
