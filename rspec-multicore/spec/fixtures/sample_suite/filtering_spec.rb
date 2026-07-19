# frozen_string_literal: true

RSpec.describe "Filtering examples", :integration do
  it "tagged with integration", :integration do
    expect(true).to be true
  end

  it "tagged with unit", :unit do
    expect(true).to be true
  end

  it "tagged with both", :integration, :unit do
    expect(true).to be true
  end

  context "with feature tag", :feature do
    it "inherits feature tag" do
      expect(1).to eq(1)
    end
  end
end

RSpec.describe "Untagged group" do
  it "has no tags" do
    expect(2).to eq(2)
  end

  it "can have example tag", :special do
    expect(3).to eq(3)
  end
end
