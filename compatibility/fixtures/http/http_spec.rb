# frozen_string_literal: true

require "net/http"

RSpec.describe "WebMock state" do
  it "uses a process-local request stub" do
    stub = stub_request(:get, "https://webmock.example.test/value").to_return(body: "stubbed")
    response = Net::HTTP.get(URI("https://webmock.example.test/value"))

    expect(response).to eq("stubbed")
    expect(stub).to have_been_requested.once
  end
end

RSpec.describe "VCR state" do
  it "replays a read-only cassette" do
    VCR.use_cassette("response") do
      response = Net::HTTP.get(URI("https://vcr.example.test/value"))
      expect(response).to eq("recorded")
    end
  end
end

RSpec.describe "WebMock failure reporting" do
  it "reports an unmet request expectation through standard RSpec events" do
    expect(WebMock).to have_requested(:get, "https://unrequested.example.test/value")
  end
end
