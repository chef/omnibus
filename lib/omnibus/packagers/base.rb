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

require 'fileutils'
require 'forwardable'
require 'erb'

module Omnibus
  class Packager::Base
    include Util

    extend Forwardable

    # The Omnibus::Project instance that we're packaging.
    attr_reader :project

    # The commands/steps to setup the file system.
    def self.setup(&block)
      if block_given?
        @setup = block
      else
        @setup
      end
    end

    # The commands/steps to validate any arguments.
    def self.validate(&block)
      if block_given?
        @validate = block
      else
        @validate
      end
    end

    # The commands/steps to build the package.
    def self.build(&block)
      if block_given?
        @build = block
      else
        @build || raise(AbstractMethod.new("#{self.class.name}.build"))
      end
    end

    # The commands/steps to cleanup any temporary files/directories.
    def self.clean(&block)
      if block_given?
        @clean = block
      else
        @clean
      end
    end

    # Create a new packager object.
    #
    # @param [Project] project
    def initialize(project)
      @project = project
    end

    #
    # Generation methods
    # ------------------------------

    # Create a directory at the given +path+.
    #
    # @param [String] path
    def create_directory(path)
      FileUtils.mkdir_p(path)
      path
    end

    # Remove the directory at the given +path+.
    #
    # @param [String] path
    def remove_directory(path)
      FileUtils.rm_rf(path)
    end

    # Purge the directory of all contents.
    #
    # @param [String] path
    def purge_directory(path)
      remove_directory(path)
      create_directory(path)
    end

    # Copy the +source+ file to the +destination+.
    #
    # @param [String] source
    # @param [String] destination
    def copy_file(source, destination)
      FileUtils.cp(source, destination)
      destination
    end

    # Remove the file at the given path.
    #
    # @param [String] pah
    def remove_file(path)
      FileUtils.rm_f(path)
    end

    # Copy the +source+ directory to the +destination+.
    #
    # @param [String] source
    # @param [String] destination
    def copy_directory(source, destination)
      FileUtils.cp_r(Dir["#{source}/*"], destination)
    end

    # Execute the command using shellout!
    #
    # @param [String] command
    def execute(command, options = {})
      options.merge! timeout: 3600, cwd: staging_dir
      shellout!(command,  options)
    end

    # Render an erb template at +source_path+ to +destination_path+ if
    # given. Otherwise template is rendered next to +source_path+
    # by removing the 'erb' extension of the template
    #
    # @param [String] source_path
    # @param [String] destination_path
    def render_template(source_path, destination_path = nil)
      return unless source_path.end_with?('.erb')

      destination_path = source_path.chomp('.erb') if destination_path.nil?

      File.open(source_path) do |file|
        erb = ERB.new(file.read)
        File.open(destination_path, 'w') do |out|
          out.write(erb.result(binding))
        end

        remove_file(source_path)
      end
    end

    #
    # Validations
    # ------------------------------

    # Validate the presence of a file.
    #
    # @param [String] path
    def assert_presence!(path)
      raise MissingAsset.new(path) unless File.exist?(path)
    end

    # Execute this packager by running the following phases in order:
    #
    #   - setup
    #   - validate
    #   - build
    #   - clean
    #
    def run!
      instance_eval(&self.class.setup)    if self.class.setup
      instance_eval(&self.class.validate) if self.class.validate
      instance_eval(&self.class.build)    if self.class.build
      instance_eval(&self.class.clean)    if self.class.clean
    end

    # The ending name of this package on disk. +Omnibus::Project+ uses this to
    # generate metadata about the package after it is built.
    #
    # @return [String]
    def package_name
      raise AbstractMethod.new("#{self.class.name}#package_name")
    end

    private

    # The path to the directory where we can throw staged files.
    #
    # @return [String]
    def staging_dir
      File.expand_path("#{Config.package_tmp}/#{underscore_name}")
    end

    # The path to the directory where the packager resources are
    # copied into from source.
    #
    # @return [String]
    def staging_resources_path
      File.expand_path("#{staging_dir}/Resources")
    end

    # The path to a resource in staging directory.
    #
    # @param [String]
    #   the name or path of the resource
    # @return [String]
    def resource(path)
      File.expand_path(File.join(staging_resources_path, path))
    end

    # The path to all the resources on the packager source.
    # Uses `resources_path` if specified in the project otherwise
    # uses the project root set in global config.
    #
    # @return [String]
    def resources_path
      base_path = if project.resources_path
                    project.resources_path
                  else
                    project.files_path
                  end

      File.expand_path(File.join(base_path, underscore_name, 'Resources'))
    end

    # The underscored equivalent of this class. This is mostly used by file
    # paths.
    #
    # @return [String]
    def underscore_name
      @underscore_name ||= self.class.name
        .split('::')
        .last
        .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
        .gsub(/([a-z\d])([A-Z])/, '\1_\2')
        .tr('-', '_')
        .downcase
    end
  end
end
