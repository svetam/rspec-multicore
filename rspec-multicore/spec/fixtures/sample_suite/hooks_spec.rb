# frozen_string_literal: true

RSpec.describe "Hooks behavior" do
  before(:all) do
    @all_counter = 0
  end

  before(:each) do
    @each_counter ||= 0
    @each_counter += 1
  end

  after(:each) do
    $stdout.puts "After each: #{@each_counter}"
  end

  after(:all) do
    $stdout.puts "After all completed"
  end

  it "runs with hooks - first" do
    @all_counter += 1
    expect(@each_counter).to eq(1)
  end

  it "runs with hooks - second" do
    @all_counter += 1
    expect(@each_counter).to eq(1)
  end

  describe "nested with hooks" do
    before(:each) do
      @nested_value = "set in nested before"
    end

    it "has access to nested before" do
      expect(@nested_value).to eq("set in nested before")
    end

    it "also has parent hooks" do
      expect(@each_counter).to eq(1)
    end
  end
end
