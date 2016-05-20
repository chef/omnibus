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

require "time"

module Omnibus
  class BuildVersionDSL
    include Logging

    # DSL to construct a build_version during the build.
    #
    # @see Omnibus::Project#build_version
    attr_reader :build_version
    attr_reader :source_type
    attr_reader :source_options
    attr_reader :output_method

    def initialize(version_string = nil, &block)
      @build_version = nil
      @source_type = nil
      @source_options = nil
      @output_method = nil

      if version_string
        self.build_version = version_string
      elsif block_given?
        instance_eval(&block)
        construct_build_version unless from_dependency?
      else
        raise "Please give me the build_version or tell me how to construct it"
      end
    end

    # DSL method to set the source of the build_version
    #
    # @param source_type [Symbol] Can be set to :git or :version
    # @param source_options [Hash] Options for the given source_type.
    # @return [void]
    def source(source_type, source_options = {})
      @source_type = source_type
      @source_options = source_options
    end

    # DSL method to set the output_format of the build_version. Only honored
    #  when source_type is set to :git
    #
    # @param output_method [Symbol] Can be set to any method on Omnibus::BuildVersion
    # @return [void]
    def output_format(output_method)
      @output_method = output_method
    end

    # Callback that is called by software objects to determine the version.
    #
    # @param dependency [Omnibus::Software] Software object that is making the callback.
    # @return [void]
    def resolve(dependency)
      if from_dependency? && version_dependency == dependency.name
        construct_build_version(dependency)
        log.info(log_key) { "Build Version is set to '#{build_version}'" }
      end
    end

    # Explains the build_version. Either gives its value or gives information about
    # how it will be constructed.
    #
    # @return [String]
    def explain
      if build_version
        "Build Version: #{build_version}"
      else
        if from_dependency?
          "Build Version will be determined from software '#{version_dependency}'"
        else
          "Build Version is not determined yet."
        end
      end
    end

    private

    # Helper function to determine if build_version will be determined from a
    # dependency.
    #
    # @return [Boolean]
    def from_dependency?
      source_options && version_dependency
    end

    # The name of the dependency that the build_version will be determined from.
    #
    # @return [String]
    def version_dependency
      source_options[:from_dependency]
    end

    def build_version=(new_version)
      @build_version = maybe_append_timestamp(new_version)
    end

    # Append the build_start_time to the given string if
    # Config.append_timestamp is true
    #
    # @param [String] version
    # @return [String]
    def maybe_append_timestamp(version)
      if Config.append_timestamp && !has_timestamp?(version)
        [version, Omnibus::BuildVersion.build_start_time].join("+")
      else
        version
      end
    end

    # Returns true if a given version string Looks like it was already
    # created with a function that added a timestamp. The goal of this
    # is to avoid breaking all of the people who are currently using
    # BuildVersion.semver to create dates.
    #
    # @param [String] version
    # @return [Boolean]
    def has_timestamp?(version)
      _ver, build_info = version.split("+")
      return false if build_info.nil?
      build_info.split(".").any? do |part|
        begin
          Time.strptime(part, Omnibus::BuildVersion::TIMESTAMP_FORMAT)
          true
        rescue ArgumentError
          false
        end
      end
    end

    # Determines the build_version based on source_type, output_method.
    #
    # @param version_source [Omnibus::Software] Software object from which the
    #   build version will be determined from. Default is nil.
    # @return [void]
    def construct_build_version(version_source = nil)
      case source_type
      when :git
        version = if version_source
                    Omnibus::BuildVersion.new(version_source.project_dir)
                  else
                    Omnibus::BuildVersion.new
                  end

        output = output_method || :semver
        self.build_version = version.send(output)
      when :version
        if version_source
          self.build_version = version_source.version
        else
          raise "Please tell me the source to get the version from"
        end
      else
        raise "I don't know how to construct a build_version using source '#{source_type}'"
      end
    end
  end
end
