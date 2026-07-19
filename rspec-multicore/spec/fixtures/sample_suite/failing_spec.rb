# frozen_string_literal: true

RSpec.describe "Failing examples" do
  it "fails test 1" do
    $stdout.puts "Output before failure"
    expect(1 + 1).to eq(3)
  end

  it "passes between failures" do
    expect(true).to be true
  end

  it "fails test 2" do
    warn "Stderr before failure"
    expect("hello").to eq("goodbye")
  end
end
