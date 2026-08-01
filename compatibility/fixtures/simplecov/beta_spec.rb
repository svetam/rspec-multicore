# frozen_string_literal: true

RSpec.describe "beta coverage" do
  it "loads code assigned to the second group" do
    require_relative "lib/beta"
    expect(CoverageBeta.call).to eq(:beta)
  end
end
