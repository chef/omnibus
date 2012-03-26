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

    NULL_ARG = Object.new


    def self.for(software)
      if software.source
        if software.source[:url] && Omnibus.config.use_s3_caching
          S3CacheFetcher.new(software)
        else
          without_caching_for(software)
        end
      else
        Fetcher.new(software)
      end
    end

    def self.without_caching_for(software)
      if software.source[:url]
        NetFetcher.new(software)
      elsif software.source[:git]
        GitFetcher.new(software)
      elsif software.source[:path]
        PathFetcher.new(software)
      else
        raise UnsupportedSourceLocation, "Don't know how to fetch software project #{software}"
      end
    end

    def self.name(name=NULL_ARG)
      @name = name unless name.equal?(NULL_ARG)
      @name
    end

    attr_reader :name
    attr_reader :source_timefile

    def initialize(software)
    end

    def log(message)
      puts "[fetcher:#{self.class.name}::#{name}] #{message}"
    end

    def description
      # Not as pretty as we'd like, but it's a sane default:
      inspect
    end

    def clean
    end

    def fetch 
    end

  end
end
