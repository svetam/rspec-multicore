# frozen_string_literal: true

RSpec.describe "Expect change matchers" do
  let(:counter) { { value: 0 } }

  it "expects change" do
    expect { counter[:value] += 1 }.to change { counter[:value] }.by(1)
  end

  it "expects change from/to" do
    counter[:value] = 5
    expect { counter[:value] = 10 }.to change { counter[:value] }.from(5).to(10)
  end

  it "expects no change" do
    expect { 1 + 1 }.not_to(change { counter[:value] })
  end

  describe "with array" do
    let(:items) { [] }

    it "expects size change" do
      expect { items << "item" }.to change { items.size }.by(1)
    end

    it "expects content change" do
      expect { items << "new" }.to change { items.empty? }.from(true).to(false)
    end
  end
end
