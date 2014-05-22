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
  class Publisher
    class << self
      #
      # Get the Publisher class that corresponds to the given backend.
      #
      # @param [#to_s] backend
      #   the backend publisher to use
      #
      # @return [~Publisher]
      #
      def for(backend)
        id = backend.to_s.capitalize
        Omnibus.const_get("#{id}Publisher")
      rescue NameError
        raise UnknownPublisher.new(backend)
      end

      #
      # Shortcut class method for creating a new instance of this class and
      # executing the publishing sequence.
      #
      # @param (see Publisher#initialize)
      #
      def publish(pattern, options = {}, &block)
        new(pattern, options).publish(&block)
      end
    end

    include Logging

    #
    # Create a new publisher from the given pattern.
    #
    # @param [String] pattern
    #   the path/pattern of the release artifact(s)
    # @param [Hash] options
    #   the list of options passed to the publisher
    #
    def initialize(pattern, options = {})
      @pattern = pattern
      @options = options.dup
    end

    #
    # The list of packages that match the pattern in the initializer.
    #
    # @return [Array<String>]
    #
    def packages
      @packages ||= Dir.glob(@pattern).map { |path| Package.new(path) }
    end

    #
    # @abstract
    #
    # @param [Proc] block
    #   if given, the block will yield the currently uploading "thing"
    #
    # @return [Array<String>]
    #   the list of uploaded packages
    #
    def publish(&_block)
      raise AbstractMethod.new("#{self.class.name}#publish")
    end

    private

    def safe_require(name)
      require name
    rescue LoadError
      raise GemNotInstalled.new(name)
    end
  end
end
