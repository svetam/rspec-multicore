# frozen_string_literal: true

RSpec.describe "Parallelization proof group 1" do
  it "sleeps and reports PID" do
    puts "GROUP1 PID: #{Process.pid}"
    sleep 0.5
    expect(true).to be true
  end
end

RSpec.describe "Parallelization proof group 2" do
  it "sleeps and reports PID" do
    puts "GROUP2 PID: #{Process.pid}"
    sleep 0.5
    expect(true).to be true
  end
end

RSpec.describe "Parallelization proof group 3" do
  it "sleeps and reports PID" do
    puts "GROUP3 PID: #{Process.pid}"
    sleep 0.5
    expect(true).to be true
  end
end
