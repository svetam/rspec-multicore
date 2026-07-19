# frozen_string_literal: true

RSpec::Matchers.define :be_positive do
  match do |actual|
    actual.is_a?(Numeric) && actual.positive?
  end

  failure_message do |actual|
    "expected #{actual} to be positive"
  end
end

RSpec::Matchers.define :have_length do |expected|
  match do |actual|
    actual.respond_to?(:length) && actual.length == expected
  end

  failure_message do |actual|
    "expected #{actual.inspect} to have length #{expected}, got #{actual.length}"
  end
end

RSpec.describe "Custom matchers" do
  it "uses be_positive" do
    expect(5).to be_positive
    expect(0.1).to be_positive
  end

  it "uses have_length" do
    expect("hello").to have_length(5)
    expect([1, 2, 3]).to have_length(3)
  end

  describe "negative cases" do
    it "negative is not positive" do
      expect(-5).not_to be_positive
    end

    it "empty has length 0" do
      expect("").to have_length(0)
    end
  end
end
