# frozen_string_literal: true

RSpec.describe "Aggregate failures" do
  it "reports multiple failures together", :aggregate_failures do
    expect(1).to eq(1)
    expect(2).to eq(2)
    expect(3).to eq(3)
  end

  it "passes with aggregate" do
    aggregate_failures "checking values" do
      expect("a").to eq("a")
      expect("b").to eq("b")
    end
  end

  describe "in nested context" do
    it "also supports aggregate", :aggregate_failures do
      expect([1, 2]).to include(1)
      expect([1, 2]).to include(2)
    end
  end
end
