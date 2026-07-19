# frozen_string_literal: true

RSpec.describe "Multiline output" do
  it "outputs multiple lines to stdout" do
    $stdout.puts "Line 1 from example 1"
    $stdout.puts "Line 2 from example 1"
    $stdout.puts "Line 3 from example 1"
    expect(true).to be true
  end

  it "outputs to both streams" do
    $stdout.puts "STDOUT: message 1"
    $stderr.puts "STDERR: message 1" # rubocop:disable Style/StderrPuts
    $stdout.puts "STDOUT: message 2"
    $stderr.puts "STDERR: message 2" # rubocop:disable Style/StderrPuts
    expect(true).to be true
  end

  it "outputs nothing" do
    expect(1 + 1).to eq(2)
  end
end

RSpec.describe "More output tests" do
  it "uses print without newline" do
    $stdout.print "No newline here"
    $stdout.puts ""
    expect(true).to be true
  end

  it "uses printf" do
    $stdout.printf("Formatted: %d + %d = %d\n", 1, 2, 3)
    expect(true).to be true
  end
end
