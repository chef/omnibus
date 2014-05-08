#
# Copyright:: Copyright (c) 2014 Chef Software, Inc.
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

module Omnibus
  class BuildVersionDsl
    attr_reader :build_version
    attr_reader :source_type
    attr_reader :source_options
    attr_reader :output_method

    def initialize(description)
      @build_version = nil
      @source_type = nil
      @source_options = nil
      @output_method = nil

      if description.is_a? String
        @build_version = description
      elsif description.is_a? Proc
        instance_eval(&description)
        construct_build_version unless from_dependency?
      else
        fail "Please give me the build_version or tell me how to construct it"
      end
    end

    def source(source_type, source_options = {})
      @source_type = source_type
      @source_options = source_options
    end

    def output_format(output_method)
      @output_method = output_method
    end

    def resolve(dependency)
      if from_dependency? && version_dependency == dependency.name
        construct_build_version(dependency)
        puts "Build Version is set to '#{build_version}'"
      end
    end

    def explain
      if build_version
        "Build Version: #{@build_version}"
      else
        if from_dependency?
          "Build Version will be determined from software '#{version_dependency}'"
        else
          "Build Version is not determined yet."
        end
      end
    end

    private

    def from_dependency?
      source_options && version_dependency
    end

    def version_dependency
      source_options[:from_dependency]
    end

    def construct_build_version(version_source = nil)
      case source_type
      when :git
        version = if version_source
                    Omnibus::BuildVersion.new(version_source.project_dir)
                  else
                    Omnibus::BuildVersion.new
                  end

        output = output_method || :semver
        @build_version = version.send(output)
      when :version
        if version_source
          @build_version = version_source.version
        else
          fail "Please tell me the source to get the version from"
        end
      else
        fail "I don't know how to construct a build_version using source '#{source_type}'"
      end
    end
  end
end
