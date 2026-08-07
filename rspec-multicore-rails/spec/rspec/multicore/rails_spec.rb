# frozen_string_literal: true

require "spec_helper"

RSpec.describe RSpec::Multicore::Rails do
  it "has the matching prerelease version" do
    expect(described_class::VERSION).to eq(RSpec::Multicore::VERSION)
    expect(described_class::VERSION).to eq("0.2.0.pre3")
  end

  it "loads the core runner patch" do
    expect(RSpec::Core::Runner).to be < RSpec::Multicore::RunnerPatch
  end
end
