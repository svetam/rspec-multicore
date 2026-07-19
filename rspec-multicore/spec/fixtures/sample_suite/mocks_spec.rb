# frozen_string_literal: true

class Service
  def call = "real result"
end

class Client
  def initialize(service) = @service = service

  def execute = @service.call
end

RSpec.describe "Mocks and doubles" do
  describe "using double" do
    it "creates a double" do
      service = double("service", call: "mocked")
      expect(service.call).to eq("mocked")
    end

    it "uses instance_double" do
      service = instance_double(Service, call: "instance mocked")
      expect(service.call).to eq("instance mocked")
    end
  end

  describe "stubbing" do
    let(:service) { Service.new }

    it "stubs method" do
      allow(service).to receive(:call).and_return("stubbed")
      expect(service.call).to eq("stubbed")
    end

    it "real method without stub" do
      expect(service.call).to eq("real result")
    end
  end

  describe "expectations" do
    it "expects method call" do
      service = double("service")
      expect(service).to receive(:call).and_return("expected")
      service.call
    end

    it "expects with arguments" do
      calculator = double("calculator")
      expect(calculator).to receive(:add).with(1, 2).and_return(3)
      expect(calculator.add(1, 2)).to eq(3)
    end
  end

  describe "spy" do
    it "uses spy for verification after" do
      service = spy("service")
      service.call
      service.another_method
      expect(service).to have_received(:call)
      expect(service).to have_received(:another_method)
    end
  end
end
