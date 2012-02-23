require 'pp'

module Omnibus

  # Base class for classes that fetch project sources from the internet.
  class Fetcher

    class ErrorReporter

      def initialize(error, fetcher)
        @error, @fetcher = error, fetcher
      end

      def e
        @error
      end

      def explain(why)
        $stderr.puts "* " * 40
        $stderr.puts why
        $stderr.puts "Fetcher params:"
        $stderr.puts indent(@fetcher.description, 2)
        $stderr.puts "Exception:"
        $stderr.puts indent("#{e.class}: #{e.message.strip}", 2)
        Array(e.backtrace).each {|l| $stderr.puts indent(l, 4) }
        $stderr.puts "* " * 40
      end

      private

      def indent(string, n)
        string.split("\n").map {|l| " ".rjust(n) << l }.join("\n")
      end

    end

    class UnsupportedSourceLocation < ArgumentError
    end


    def self.for(software)
      if software.source[:url]
        NetFetcher.new(software)
      elsif software.source[:git]
        GitFetcher.new(software)
      else
        raise UnsupportedSourceLocation, "Don't know how to fetch software project #{software}"
      end
    end

    def description
      # Not as pretty as we'd like, but it's a sane default:
      inspect
    end

    def fetch
      raise NotImplementedError, "define #fetcher for class #{self.class}"
    end

  end
end
