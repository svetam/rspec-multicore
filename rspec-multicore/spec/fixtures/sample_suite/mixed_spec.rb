# frozen_string_literal: true

RSpec.describe "Mixed examples" do
  it "passes with output" do
    $stdout.puts "Line 1"
    $stdout.puts "Line 2"
    warn "Error line"
    expect(10).to be > 5
  end

  it "fails with output" do
    $stdout.puts "Before failure"
    expect([]).not_to be_empty
  end

  it "passes silently" do
    expect(nil).to be_nil
  end
end
