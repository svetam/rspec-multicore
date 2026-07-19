# frozen_string_literal: true

RSpec.describe "Pending variations" do
  it "uses pending block" do
    pending "waiting for implementation"
    expect(false).to be true
  end

  xit "uses xit" do
    expect(false).to be true
  end

  it "uses skip" do
    skip "skipping this test"
    expect(false).to be true
  end

  it "pending that passes unexpectedly" do
    pending "should fail but passes"
    expect(true).to be true
  end

  describe "xdescribe is not standard" do
    it "but skip in describe works" do
      expect(true).to be true
    end
  end
end

RSpec.describe "Another pending group" do
  it "normal passing test" do
    expect(1).to eq(1)
  end

  it "uses pending with reason" do
    pending("specific reason here")
    raise "not implemented"
  end
end
