# frozen_string_literal: true

RSpec.describe RSpec::Multicore::Channel do
  let(:left) { channels.first }
  let(:right) { channels.last }
  let(:channels) { described_class.pair }

  after { channels.each(&:close) }

  it "transfers plain frames in order" do
    left.write([:first, { value: 1 }])
    left.write([:second, nil])

    expect(right.read).to eq([:first, { value: 1 }])
    expect(right.read).to eq([:second, nil])
  end

  it "returns nil after the peer closes" do
    left.close

    expect(right.read).to be_nil
  end

  it "reports a partial header" do
    left.socket.write("\x00\x01")
    left.close

    expect { right.read }.to raise_error(RSpec::Multicore::Error, /closed during header/)
  end

  it "reports a partial frame" do
    left.socket.write("#{[8].pack("N")}short")
    left.close

    expect { right.read }.to raise_error(RSpec::Multicore::Error, /closed during frame/)
  end

  it "rejects corrupt and oversized frames" do
    left.socket.write("#{[4].pack("N")}nope")
    expect { right.read }.to raise_error(RSpec::Multicore::Error, /Invalid Channel frame/)

    left.socket.write([described_class::MAX_FRAME_SIZE + 1].pack("N"))
    expect { right.read }.to raise_error(RSpec::Multicore::Error, /frame size/)
  end

  it "rejects arbitrary objects" do
    expect { left.write(Object.new) }.to raise_error(RSpec::Multicore::Error, /cannot transfer/)
  end

  it "rejects arbitrary objects received from a peer" do
    payload = Marshal.dump(Object.new)
    left.socket.write([payload.bytesize].pack("N") + payload)

    expect { right.read }.to raise_error(RSpec::Multicore::Error, /cannot transfer/)
  end

  it "keeps frames intact with concurrent writers" do
    threads = 4.times.map do |thread|
      Thread.new { 25.times { |index| left.write([thread, index]) } }
    end
    threads.each(&:join)

    frames = 100.times.map { right.read }
    expect(frames.uniq.size).to eq(100)
  end

  it "closes both descriptors" do
    channels.each(&:close)

    expect(channels).to all(be_closed)
  end
end
