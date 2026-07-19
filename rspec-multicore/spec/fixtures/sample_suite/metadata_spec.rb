# frozen_string_literal: true

RSpec.describe "Metadata handling", :slow do
  it "has describe-level metadata", :fast do |example|
    expect(example.metadata[:slow]).to be true
    expect(example.metadata[:fast]).to be true
  end

  it "inherits metadata" do |example|
    expect(example.metadata[:slow]).to be true
  end

  describe "nested with metadata", :database do
    it "has nested metadata" do |example|
      expect(example.metadata[:database]).to be true
      expect(example.metadata[:slow]).to be true
    end
  end

  context "with type metadata", type: :model do
    it "has type" do |example|
      expect(example.metadata[:type]).to eq(:model)
    end
  end
end

RSpec.describe "Another group for metadata" do
  it "does not have slow metadata" do |example|
    expect(example.metadata[:slow]).to be_nil
  end
end
