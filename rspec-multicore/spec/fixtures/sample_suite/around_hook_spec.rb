# frozen_string_literal: true

RSpec.describe "Around hooks" do
  around(:each) do |example|
    $stdout.puts "Before around: #{example.description}"
    example.run
    $stdout.puts "After around: #{example.description}"
  end

  it "runs with around hook" do
    $stdout.puts "Inside example"
    expect(true).to be true
  end

  it "runs another with around hook" do
    expect(1 + 1).to eq(2)
  end

  describe "nested around" do
    around(:each) do |example|
      $stdout.puts "Nested around start"
      example.run
      $stdout.puts "Nested around end"
    end

    it "has both around hooks" do
      expect("test").to include("test")
    end
  end
end
