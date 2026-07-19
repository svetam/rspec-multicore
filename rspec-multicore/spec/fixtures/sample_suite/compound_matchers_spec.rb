# frozen_string_literal: true

RSpec.describe "Compound matchers" do
  it "uses and" do
    expect(5).to be > 0 and be < 10
  end

  it "uses or" do
    expect("hello").to start_with("h").or end_with("x")
  end

  it "combines multiple expectations" do
    value = [1, 2, 3]
    expect(value).to include(1).and include(2)
  end

  describe "with arrays" do
    let(:items) { %w[apple banana cherry] }

    it "all match" do
      expect(items).to all(be_a(String))
    end

    it "all satisfy" do
      expect(items).to all(have_attributes(length: be > 3))
    end
  end

  describe "contain_exactly" do
    it "matches regardless of order" do
      expect([3, 1, 2]).to contain_exactly(1, 2, 3)
    end
  end
end
