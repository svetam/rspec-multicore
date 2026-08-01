# frozen_string_literal: true

RSpec.describe "retried group" do
  it "reports only its final successful result", retry: 2 do
    @attempts = @attempts.to_i + 1
    CompatibilityEvidence.record(attempt: @attempts) if @attempts == 2
    expect(@attempts).to eq(2)
  end
end

RSpec.describe "stable group" do
  it "reports its successful result once" do
    expect(:stable).to eq(:stable)
  end
end
