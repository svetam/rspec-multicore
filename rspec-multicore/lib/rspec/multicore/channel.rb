# frozen_string_literal: true

require "socket"

module RSpec
  module Multicore
    # Transfers bounded plain-value frames over a local socket pair.
    class Channel
      HEADER_SIZE = 4
      MAX_FRAME_SIZE = 10 * 1024 * 1024
      PLAIN_VALUES = [NilClass, TrueClass, FalseClass, Integer, Float, String, Symbol].freeze

      attr_reader :socket

      def self.pair = UNIXSocket.pair.map { new(_1) }

      def initialize(socket)
        @socket = socket
        @write_lock = Mutex.new
      end

      def write(value)
        validate!(value)
        payload = Marshal.dump(value)
        raise Error, "Channel frame exceeds #{MAX_FRAME_SIZE} bytes" if payload.bytesize > MAX_FRAME_SIZE

        @write_lock.synchronize { write_all([payload.bytesize].pack("N") + payload) }
        nil
      rescue IOError, SystemCallError => e
        raise Error, "Channel write failed: #{e.message}"
      end

      def read
        header = read_exactly(HEADER_SIZE)
        return if header.nil?

        length = header.unpack1("N")
        raise Error, "Invalid Channel frame size: #{length}" unless length.between?(1, MAX_FRAME_SIZE)

        payload = read_exactly(length, "frame")

        value = Marshal.load(payload)
        validate!(value)
        value
      rescue TypeError, ArgumentError => e
        raise Error, "Invalid Channel frame: #{e.message}"
      end

      def close
        socket.close unless socket.closed?
      rescue IOError, SystemCallError
        nil
      end

      def closed? = socket.closed?

      private

      def read_exactly(length, part = "header")
        data = +""
        while data.bytesize < length
          chunk = socket.read(length - data.bytesize)
          if chunk.nil? || chunk.empty?
            return if data.empty? && part == "header"

            raise Error, "Channel closed during #{part}"
          end

          data << chunk
        end
        data
      rescue IOError, SystemCallError => e
        raise Error, "Channel read failed: #{e.message}"
      end

      def write_all(data)
        offset = 0
        offset += socket.write(data.byteslice(offset..)) while offset < data.bytesize
      end

      def validate!(value)
        return if PLAIN_VALUES.any? { value.is_a?(_1) }
        return value.each { validate!(_1) } if value.is_a?(Array)

        if value.is_a?(Hash)
          return value.each do |key, item|
            validate!(key)
            validate!(item)
          end
        end

        raise Error, "Channel cannot transfer #{value.class}"
      end
    end
  end
end
