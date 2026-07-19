# frozen_string_literal: true

RSpec.describe "Slow group 1" do
  it "takes a moment" do
    sleep 0.05
    expect(true).to be true
  end

  it "also takes a moment" do
    sleep 0.05
    expect(1).to eq(1)
  end
end

RSpec.describe "Fast group" do
  it "is quick 1" do
    expect(2).to eq(2)
  end

  it "is quick 2" do
    expect(3).to eq(3)
  end

  it "is quick 3" do
    expect(4).to eq(4)
  end
end

RSpec.describe "Slow group 2" do
  it "also slow" do
    sleep 0.05
    expect(5).to eq(5)
  end
end
