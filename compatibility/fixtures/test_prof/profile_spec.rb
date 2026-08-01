# frozen_string_literal: true

RSpec.describe "first profiled group" do
  it "records a worker-owned factory event" do
    profile_factory(:first)
  end
end

RSpec.describe "second profiled group" do
  it "records another worker-owned factory event" do
    profile_factory(:second)
  end
end

def profile_factory(name)
  value = TestProf::FactoryProf.track(name, variation: []) { name.to_s }
  expect(value).to eq(name.to_s)
end
