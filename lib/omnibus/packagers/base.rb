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

require 'fileutils'
require 'forwardable'
require 'omnibus/util'

module Omnibus
  class Packager::Base
    include Util

    extend Forwardable

    # The Omnibus::Project instance that we're packaging.
    attr_reader :project

    # !@method name
    #   @return (see Project#name)
    def_delegator :@project, :name

    # !@method version
    #   @return (see Project#build_version)
    def_delegator :@project, :build_version, :version

    # !@method iteration
    #   @return (see Project#iteration)
    def_delegator :@project, :iteration, :iteration

    # !@method identifier
    #   @return (see Project#mac_pkg_identifier)
    def_delegator :@project, :mac_pkg_identifier, :identifier

    # !@method install_path
    #   @return (see Project#install_path)
    def_delegator :@project, :install_path, :install_path

    # !@method scripts
    #   @return (see Project#package_scripts_path)
    def_delegator :@project, :package_scripts_path, :scripts

    # !@method files_path
    #   @return (see Project#files_path)
    def_delegator :@project, :files_path

    # !@method package_dir
    #   @return (see Project#package_dir)
    def_delegator :@project, :package_dir

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
        @build || fail(AbstractMethod.new("#{self.class.name}.build"))
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

    # Execute the command using shellout!
    #
    # @param [String] command
    def execute(command)
      shellout!(command,  timeout: 3600, cwd: staging_dir)
    end

    #
    # Validations
    # ------------------------------

    # Validate the presence of a file.
    #
    # @param [String] path
    def assert_presence!(path)
      fail MissingAsset.new(path) unless File.exist?(path)
    end

    # Execute this packager by running the following phases in order:
    #
    #   - setup
    #   - validate
    #   - build
    #   - clean
    #
    def run!
      instance_eval(&self.class.validate) if self.class.validate
      instance_eval(&self.class.setup)    if self.class.setup
      instance_eval(&self.class.build)    if self.class.build
      instance_eval(&self.class.clean)    if self.class.clean
    end

    # The ending name of this package on disk. +Omnibus::Project+ uses this to
    # generate metadata about the package after it is built.
    #
    # @return [String]
    def package_name
      fail AbstractMethod.new("#{self.class.name}#package_name")
    end

    private

    # The path to the directory where we can throw staged files.
    #
    # @return [String]
    def staging_dir
      File.expand_path("#{project.package_tmp}/#{underscore_name}")
    end

    # The path to a local resource on disk.
    #
    # @param [String]
    #   the name or path of the resource
    # @return [String]
    def resource(path)
      File.expand_path("#{resources_path}/#{path}")
    end

    # The path to all the resources on the local file system.
    #
    # @return [String]
    def resources_path
      File.expand_path("#{project.files_path}/#{underscore_name}/Resources")
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
