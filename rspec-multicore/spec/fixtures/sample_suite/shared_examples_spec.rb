# frozen_string_literal: true

RSpec.shared_examples "a collection" do
  it "responds to each" do
    expect(collection).to respond_to(:each)
  end

  it "responds to size" do
    expect(collection).to respond_to(:size)
  end

  it "has expected size" do
    expect(collection.size).to eq(expected_size)
  end
end

RSpec.shared_context "with logged output" do
  before do
    $stdout.puts "Shared context setup for: #{self.class.description}"
  end

  let(:log_prefix) { "[LOG]" }
end

RSpec.describe "Array collection" do
  let(:collection) { [1, 2, 3] }
  let(:expected_size) { 3 }

  include_examples "a collection"

  it "is an array" do
    expect(collection).to be_an(Array)
  end
end

RSpec.describe "Hash collection" do
  let(:collection) { { a: 1, b: 2 } }
  let(:expected_size) { 2 }

  include_examples "a collection"

  it "is a hash" do
    expect(collection).to be_a(Hash)
  end
end

RSpec.describe "With shared context" do
  include_context "with logged output"

  it "has log prefix from shared context" do
    expect(log_prefix).to eq("[LOG]")
  end

  it "prints setup message" do
    expect(true).to be true
  end
end
