require 'logger'

module Omnibus
  class Logger < ::Logger
    def initialize(logdev = $stdout, *)
      super
      @level = Logger::WARN
    end

    #
    # Print a deprecation warning.
    #
    # @see (Logger#add)
    #
    def deprecated(progname = nil, &block)
      if level <= WARN
        add(WARN, 'DEPRECATED: ' + (block ? yield : progname), progname)
      end
    end

    #
    # Set the log lever for this logger instance.
    #
    # @example
    #   logger.level = :info
    #
    # @param [Symbol] level
    #
    def level=(level)
      @level = ::Logger.const_get(level.to_s.upcase)
    rescue NameError
      raise "'#{level.inspect}' does not appear to be a valid log level!"
    end

    #
    # The live stream for this logger.
    #
    # @param [Symbol] level
    #
    # @return [LiveStream]
    #
    def live_stream(level = :debug)
      @live_streams ||= {}
      @live_streams[level.to_sym] ||= LiveStream.new(self, level)
    end

    private

    def format_message(severity, _datetime, progname, msg)
      left = if progname
               "[#{progname}] #{severity[0]} | "
             else
               "#{severity[0]} | "
             end

      "#{left.rjust(30)}#{msg}\n"
    end

    #
    # This is a magical wrapper around the logger that chunks data to not look
    # like absolute shit.
    #
    class LiveStream
      #
      # Create a new LiveStream logger.
      #
      # @param [Logger] log
      #   the logger object responsible for logging
      # @param [Symbol] level
      #   the log level
      #
      def initialize(log, level = :debug)
        @log = log
        @level = level
        @buffer = ''
      end

      #
      # The live stream operator must respond to <<.
      #
      # @param [String] data
      #
      def <<(data)
        log_lines(data)
      end

      private

      #
      # Log the lines in the data, keeping the "rest" in the buffer.
      #
      # @param [String] data
      #
      def log_lines(data)
        if (leftover = @buffer)
          @buffer = nil
          log_lines(leftover + data)
        else
          if (newline_index = data.index("\n"))
            line = data.slice!(0...newline_index)
            data.slice!(0)
            log_line(line)
            log_lines(data)
          else
            @buffer = data
          end
        end
      end

      #
      # Log an individual line.
      #
      # @param [String] data
      #
      def log_line(data)
        @log.public_send(@level) { data }
      end
    end
  end
end
