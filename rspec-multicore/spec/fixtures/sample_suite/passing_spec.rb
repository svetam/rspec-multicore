# frozen_string_literal: true

RSpec.describe "Passing examples" do
  it "passes test 1" do
    $stdout.puts "Output from passing test 1"
    expect(1 + 1).to eq(2)
  end

  it "passes test 2" do
    warn "Stderr from passing test 2"
    expect("hello").to match(/hello/)
  end

  it "passes test 3" do
    expect([1, 2, 3]).to include(2)
  end
end
