# frozen_string_literal: true

RSpec.describe "Output matchers" do
  it "matches stdout output" do
    expect { print "hello" }.to output("hello").to_stdout
  end

  it "matches stderr output" do
    expect { warn "warning" }.to output(/warning/).to_stderr
  end

  it "matches with regex" do
    expect { puts "Hello World" }.to output(/World/).to_stdout
  end

  it "expects no output" do
    expect { 1 + 1 }.not_to output.to_stdout
  end
end

RSpec.describe "More output tests" do
  it "multiline output" do
    expect do
      puts "line1"
      puts "line2"
    end.to output("line1\nline2\n").to_stdout
  end
end
