module TransportGateway
  module Sources
    class StringIoSource
      attr_reader :stream, :size
      def initialize(string)
        @size = string.bytesize
        @stream = StringIO.new(string)
      end

      def cleanup
        @stream = nil
      end
    end
  end
end
