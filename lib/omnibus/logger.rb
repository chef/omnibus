#
# Copyright 2014 Chef Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module Omnibus
  class Logger

    require "time"

    #
    # The amount of padding on the left column.
    #
    # @return [Fixnum]
    #
    LEFT = 30

    #
    # Our custom log levels, in order of severity
    #
    # @return [Array]
    #
    LEVELS = %w{UNKNOWN INTERNAL DEBUG INFO WARN ERROR FATAL NOTHING}.freeze

    #
    # The mutex lock for synchronizing IO writing.
    #
    # @return [Mutex]
    #
    MUTEX = Mutex.new

    attr_reader :io
    attr_reader :level

    #
    # Create a new logger object.
    #
    # @param [IO] io
    #   the IO object to read/write
    #
    def initialize(io = $stdout)
      @io = io
      @level = LEVELS.index("WARN")
    end

    LEVELS.each.with_index do |level, index|
      class_eval <<-EOH, __FILE__, __LINE__
        def #{level.downcase}(progname, &block)
          add(#{index}, progname, &block)
        end
      EOH
    end

    #
    # Print a deprecation warning. This actually outputs to +WARN+, but is
    # prefixed with the string "DEPRECATED" first.
    #
    # @see (Logger#add)
    #
    def deprecated(progname, &block)
      meta = Proc.new { "DEPRECATED: #{yield}" }
      add(LEVELS.index("WARN"), progname, &meta)
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
      @level = LEVELS.index(level.to_s.upcase) || -1
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

    #
    # Add a message to the logger with the given severity and progname.
    #
    def add(severity, progname, &block)
      return true if io.nil? || severity < level
      message = format_message(severity, progname, yield)
      MUTEX.synchronize { io.write(message) }
      true
    end

    #
    # The string representation of this object.
    #
    # @return [String]
    #
    def to_s
      "#<#{self.class.name}>"
    end

    #
    # The detailed string representation of this object.
    #
    # @return [String]
    #
    def inspect
      "#<#{self.class.name} level: #{@level}>"
    end

    private

    #
    # Format the log message.
    #
    # @return [String]
    #
    def format_message(severity, progname, message)
      if progname
        left = "[#{progname}] #{format_severity(severity)} | "
      else
        left = "#{format_severity(severity)} | "
      end
      "#{left.rjust(LEFT)}#{Time.now.iso8601()} | #{message}\n"
    end

    #
    # Format the log severity.
    #
    # @return [String]
    #
    def format_severity(severity)
      if severity == 0
        "_"
      else
        (LEVELS[severity] || "?")[0]
      end
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
        @buffer = ""
      end

      #
      # The live stream operator must respond to <<.
      #
      # @param [String] data
      #
      def <<(data)
        log_lines(data)
      end

      #
      # The string representation of this object.
      #
      # @return [String]
      #
      def to_s
        "#<#{self.class.name}>"
      end

      #
      # The detailed string representation of this object.
      #
      # @return [String]
      #
      def inspect
        "#<#{self.class.name} level: #{@level}>"
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
        @log.public_send(@level, nil) { data }
      end
    end
  end
end
