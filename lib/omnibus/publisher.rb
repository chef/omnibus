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

      if @options[:platform]
        log.warn(log_key) do
          "Publishing platform has been overriden to '#{@options[:platform]}'"
        end
      end

      if @options[:platform_version]
        log.warn(log_key) do
          "Publishing platform version has been overriden to '#{@options[:platform_version]}'"
        end
      end
    end

    #
    # The list of packages that match the pattern in the initializer.
    #
    # @return [Array<String>]
    #
    def packages
      @packages ||= FileSyncer.glob(@pattern).map { |path| Package.new(path) }
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

    #
    # The platform to publish a package for. A publisher can be optionally
    # initialized with a platform which should be used in all publishing
    # logic. This allows a package built on one platform to be published
    # for another platform. For example, one might build on Ubuntu and
    # test/publish on Ubuntu and Debian.
    #
    # @note Even if a glob pattern matches multiple packages (potentially
    #   across multiple platforms) all packages will be published for the
    #   same platform.
    #
    # @param [Package] package
    #
    # @return [String]
    #
    def publish_platform(package)
      @options[:platform] || package.metadata[:platform]
    end

    #
    # The platform version to publish a package for. A publisher can be
    # optionally initialized with a platform version which should be used
    # in all publishing logic. This allows a package built on one
    # platform to be published for another platform version. For example,
    # one might build on Ubuntu 10.04 and test/publish on Ubuntu 10.04
    # and 12.04.
    #
    # @note Even if a glob pattern matches multiple packages (potentially
    #   across multiple platforms) all packages will be published for the
    #   same platform version.
    #
    # @param [Package] package
    #
    # @return [String]
    #
    def publish_platform_version(package)
      @options[:platform_version] || package.metadata[:platform_version]
    end

    def safe_require(name)
      require name
    rescue LoadError
      raise GemNotInstalled.new(name)
    end
  end
end
