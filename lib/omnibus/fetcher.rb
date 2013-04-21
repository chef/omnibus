#
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# License:: Apache License, Version 2.0
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

require 'pp'

module Omnibus

  # Base class for classes that fetch project sources from the internet.
  #
  # @abstract Subclass and override the {#clean}, {#description},
  #   {#fetch}, {#fetch_required?}, and {#version_guid} methods
  #
  # @todo Is this class supposed to be abstract or not?  Pretty sure
  #   it's supposed to be abstract
  class Fetcher

    # Given an error and a fetcher that generated the error, print a
    # formatted report of the error and stacktrace, along with fetcher
    # details to stderr.
    #
    # @note Does not rethrow the error; that must currently be done manually.
    #
    # @todo Since this is always called from within a fetcher, and
    #   since the fetcher always passes itself in in the {#initialize}
    #   method, this really ought to be encapsulated in a method call on
    #   {Omnibus::Fetcher}.
    # @todo Also, since we always 'raise' after calling {#explain}, we
    #   should just go ahead and exit from here.  No need to raise,
    #   since we're already outputting the real error and stacktrace
    #   here.
    class ErrorReporter

      def initialize(error, fetcher)
        @error, @fetcher = error, fetcher
      end

      # @todo Why not just make an attribute for error?
      #
      # @todo And for that matter, why not make an attribute for the
      #   fetcher as well?  Or why not just use `@error` like we use
      #   `@fetcher`?
      def e
        @error
      end

      # @todo If {Omnibus::Fetcher#description} is meant to show
      #   parameters (presumably the kind of fetcher and the software it
      #   is fetching?),
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

      # Indent each line of a string with `n` spaces.
      #
      # Splits the string at `\n` characters and then pads the left
      # side with `n` spaces.  Rejoins them all again with `\n`.
      #
      # @param string [String] the string to indent
      # @param n [Fixnum] the number of " " characters to indent each line.
      # @return [String]
      def indent(string, n)
        string.split("\n").map {|l| " ".rjust(n) << l }.join("\n")
      end

    end

    class UnsupportedSourceLocation < ArgumentError
    end

    NULL_ARG = Object.new

    # Returns an implementation of {Fetcher} that can retrieve the
    # given software.
    #
    # @param software [Omnibus::Software] the software the Fetcher should fetch
    # @return [Omnibus::Fetcher]
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

    # @param software [Omnibus::Software] the software to fetch
    # @raise [UnsupportedSourceLocation] if the software's source is not
    #   one of `:url`, `:git`, or `:path`
    # @see Omnibus::Software#source
    # @todo Define an enumeration of the acceptable software types
    # @todo This probably ought to be folded into {#for} method above.
    #   It looks like this is called explicitly in
    #   {Omnibus::S3Cache#fetch}, but that could be handled by having a
    #   second optional parameter that always disables caching.
    # @todo Since the software determines what fetcher must be used to
    #   fetch it, perhaps this should be a method on {Omnibus::Software}
    #   instead.
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

    # @todo What is this?  It doesn't appear to be used anywhere
    attr_reader :source_timefile

    def initialize(software)
    end

    def log(message)
      puts "[fetcher:#{self.class.name}::#{name}] #{message}"
    end

    # @!group Methods for Subclasses to Implement

    # @todo All extenders of this class override this method.  Since
    #   this class appears to be intended as an abstract one, this
    #   should raise a NotImplementedError
    def description
      # Not as pretty as we'd like, but it's a sane default:
      inspect
    end

    # @todo All extenders of this class override this method.  Since
    #   this class appears to be intended as an abstract one, this
    #   should raise a NotImplementedError
    def fetch_required?
      false
    end

    # @todo Empty method is very suspicious; raise NotImplementedError instead.
    def clean
    end

    # @todo Empty method is very suspicious; raise NotImplementedError instead.
    def fetch
    end

    # @todo Empty method is very suspicious; raise NotImplementedError instead.
    def version_guid
    end

    # !@endgroup
  end
end
