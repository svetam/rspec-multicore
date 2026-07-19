# frozen_string_literal: true

class CustomError < StandardError; end

RSpec.describe "Exception handling" do
  it "expects raised error" do
    expect { raise CustomError, "boom" }.to raise_error(CustomError, "boom")
  end

  it "expects raised error with message match" do
    expect { raise "something went wrong" }.to raise_error(/went wrong/)
  end

  it "expects no error" do
    expect { 1 + 1 }.not_to raise_error
  end

  it "catches and reports unexpected error" do
    expect { raise "unexpected" }.to raise_error(RuntimeError)
  end

  describe "error in before hook" do
    before do
      @setup_complete = true
    end

    it "runs after successful before" do
      expect(@setup_complete).to be true
    end
  end

  describe "throw and catch" do
    it "handles throw" do
      result = catch(:done) do
        throw :done, "finished"
      end
      expect(result).to eq("finished")
    end
  end
end
