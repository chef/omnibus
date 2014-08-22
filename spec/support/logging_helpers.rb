module Omnibus
  module RSpec
    module LoggingHelpers
      #
      # Grab the result of the log command. Since Omnibus uses the block form of
      # the logger, this method handles both types of logging.
      #
      # @example
      #   output = capture_logging { some_command }
      #   expect(output).to include('whatever')
      #
      def capture_logging
        original = Omnibus.logger
        Omnibus.logger = TestLogger.new
        yield
        Omnibus.logger.output
      ensure
        Omnibus.logger = original
      end

      class TestLogger < Logger
        def initialize(*)
          super(StringIO.new)
          @level = -1
        end

        def output
          io.string
        end
      end
    end
  end
end
