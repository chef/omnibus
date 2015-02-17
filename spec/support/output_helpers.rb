module Omnibus
  module RSpec
    module OutputHelpers
      #
      # Capture stdout within this block.
      #
      def capture_stdout(&block)
        old = $stdout
        $stdout = fake = StringIO.new
        yield
        fake.string
      ensure
        $stdout = old
      end

      #
      # Capture stderr within this block.
      #
      def capture_stderr(&block)
        old = $stderr
        $stderr = fake = StringIO.new
        yield
        fake.string
      ensure
        $stderr = old
      end
    end
  end
end
