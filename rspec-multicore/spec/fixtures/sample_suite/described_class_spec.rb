# frozen_string_literal: true

class Calculator
  def add(a, b) = a + b
  def subtract(a, b) = a - b
  def multiply(a, b) = a * b
end

RSpec.describe Calculator do
  subject { described_class.new }

  it "has described_class" do
    expect(described_class).to eq(Calculator)
  end

  it "can instantiate via described_class" do
    instance = described_class.new
    expect(instance).to be_a(Calculator)
  end

  describe "#add" do
    it "adds two numbers" do
      expect(subject.add(2, 3)).to eq(5)
    end
  end

  describe "#subtract" do
    it "subtracts two numbers" do
      expect(subject.subtract(5, 3)).to eq(2)
    end
  end

  describe "#multiply" do
    it "multiplies two numbers" do
      expect(subject.multiply(4, 3)).to eq(12)
    end
  end
end
