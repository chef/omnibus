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

    private

    def format_message(severity, _datetime, progname, msg)
      out = "#{severity[0]} | #{msg}\n"
      out = "[#{progname}] #{out}" if progname
      out
    end
  end
end
