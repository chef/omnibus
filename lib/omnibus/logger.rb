require 'logger'

module Omnibus
  class Logger < ::Logger
    #
    # The width of the label on the left
    #
    # @return [Fixnum]
    #
    LEFT = 40

    #
    # The width of the output text.
    #
    # @return [Fixnum]
    #
    RIGHT = 80

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

    private

    def format_message(severity, _datetime, progname, msg)
      msg = msg.split("\n").map do |line|
        if line.length > RIGHT
          line.gsub(/(.{1,#{RIGHT}})(\s+|$)/, "\\1\n").strip
        else
          line
        end
      end.join("\n")

      msg = msg.split("\n").collect.with_index do |line, index|
        if index == 0
          line
        else
          ' ' * LEFT + line
        end
      end.join("\n")

      left = "#{severity[0]} | "
      left = "[#{progname}] #{left}" if progname
      left = left.rjust(LEFT)

      "#{left}#{msg}\n"
    end
  end
end
