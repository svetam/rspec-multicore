# frozen_string_literal: true

RSpec.describe "Let and subject" do
  let(:simple_value) { 42 }
  let(:computed_value) { simple_value * 2 }
  let!(:eager_value) { "eager" }

  subject { { key: simple_value } }

  it "uses let" do
    expect(simple_value).to eq(42)
  end

  it "uses computed let" do
    expect(computed_value).to eq(84)
  end

  it "uses eager let!" do
    expect(eager_value).to eq("eager")
  end

  it "uses subject" do
    expect(subject[:key]).to eq(42)
  end

  describe "with overridden let" do
    let(:simple_value) { 100 }

    it "sees overridden value" do
      expect(simple_value).to eq(100)
      expect(computed_value).to eq(200)
    end
  end

  context "with named subject" do
    subject(:my_hash) { { name: "test" } }

    it "can use named subject" do
      expect(my_hash[:name]).to eq("test")
    end

    it "subject and named are same" do
      expect(subject).to eq(my_hash)
    end
  end
end
