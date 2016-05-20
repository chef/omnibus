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
    include Digestable

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
    #
    # @param [Hash] options
    #   the list of options passed to the publisher
    # @option options [Hash] :platform_mappings A simple
    #   mapping of build to publish platform(s)
    # @example
    #   {
    #     'ubuntu-10.04' => [
    #       'ubuntu-10.04',
    #       'ubuntu-12.04',
    #       'ubuntu-14.04',
    #     ],
    #   }
    #
    def initialize(pattern, options = {})
      @pattern = pattern
      @options = options.dup

      if @options[:platform_mappings]
        log.info(log_key) do
          "Publishing will be performed using provided platform mappings."
        end
      end
    end

    #
    # The list of packages that match the pattern in the initializer.
    #
    # @return [Array<String>]
    #
    def packages
      @packages ||= begin
        publish_packages = Array.new
        build_packages   = FileSyncer.glob(@pattern).map { |path| Package.new(path) }

        if @options[:platform_mappings]
          # the platform map is a simple hash with publish to build platform mappings
          @options[:platform_mappings].each_pair do |build_platform, publish_platforms|
            # Splits `ubuntu-12.04` into `ubuntu` and `12.04`
            build_platform, build_platform_version = build_platform.rpartition("-") - %w{ - }

            # locate the package for the build platform
            packages = build_packages.select do |p|
              p.metadata[:platform] == build_platform &&
                p.metadata[:platform_version] == build_platform_version
            end

            if packages.empty?
              log.warn(log_key) do
                "Could not locate a package for build platform #{build_platform}-#{build_platform_version}. " \
                "Publishing will be skipped for: #{publish_platforms.join(', ')}"
              end
            end

            publish_platforms.each do |publish_platform|
              publish_platform, publish_platform_version = publish_platform.rpartition("-") - %w{ - }

              packages.each do |p|
                # create a copy of our package before mucking with its metadata
                publish_package  = p.dup
                publish_metadata = p.metadata.dup.to_hash

                # override the platform and platform version in the metadata
                publish_metadata[:platform]         = publish_platform
                publish_metadata[:platform_version] = publish_platform_version

                # Set the updated metadata on the package object
                publish_package.metadata = Metadata.new(publish_package, publish_metadata)

                publish_packages << publish_package
              end
            end
          end
        else
          publish_packages.concat(build_packages)
        end

        if publish_packages.empty?
          log.info(log_key) { "No packages found, skipping publish" }
        end

        publish_packages
      end
    end

    #
    # @abstract
    #
    # @param [Proc] _block
    #   if given, the block will yield the currently uploading "thing"
    #
    # @return [Array<String>]
    #   the list of uploaded packages
    #
    def publish(&_block)
      raise NotImplementedError
    end

    private

    def safe_require(name)
      require name
    rescue LoadError
      raise GemNotInstalled.new(name)
    end
  end
end
