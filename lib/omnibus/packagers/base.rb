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

module Omnibus
  class Packager::Base
    include Cleanroom
    include Digestable
    include Logging
    include NullArgumentable
    include Templating
    include Util

    # The Omnibus::Project instance that we're packaging.
    attr_reader :project

    class << self
      #
      # Set the unique of this packager.
      #
      # @see {#id}
      #
      # @param [Symbol] name
      #   the id
      #
      def id(name)
        class_eval <<-EOH, __FILE__, __LINE__
          def id
            :#{name}
          end
        EOH
      end

      # The commands/steps use to setup the filesystem.
      def setup(&block)
        if block
          @setup = block
        else
          @setup
        end
      end

      # The commands/steps to build the package.
      def build(&block)
        if block
          @build = block
        else
          @build
        end
      end
    end

    #
    # Create a new packager object.
    #
    # @param [Project] project
    #
    def initialize(project)
      @project = project
    end

    #
    # The unique identifier for this class - this is used in file paths and
    # packager searching, so please do not change unless you know what you are
    # doing!
    #
    # @abstract Subclasses should define the +id+ attribute.
    #
    # @return [Symbol]
    #
    def id
      raise NotImplementedError
    end

    #
    # The ending name of this package on disk. +Omnibus::Project+ uses this to
    # generate metadata about the package after it is built.
    #
    # @abstract
    #
    # @return [String]
    #
    def package_name
      raise NotImplementedError
    end

    #
    # @!group File system helpers
    # --------------------------------------------------

    #
    # Create a directory at the given +path+.
    #
    # @param [String] path
    #
    def create_directory(path)
      FileUtils.mkdir_p(path)
      path
    end

    #
    # Remove the directory at the given +path+.
    #
    # @param [String] path
    #
    def remove_directory(path)
      FileUtils.rm_rf(path)
    end

    #
    # Purge the directory of all contents.
    #
    # @param [String] path
    #
    def purge_directory(path)
      remove_directory(path)
      create_directory(path)
    end

    #
    # Copy the +source+ file to the +destination+.
    #
    # @param [String] source
    # @param [String] destination
    #
    def copy_file(source, destination)
      FileUtils.cp(source, destination)
      destination
    end

    #
    # Remove the file at the given path.
    #
    # @param [String] path
    #
    def remove_file(path)
      FileUtils.rm_f(path)
    end

    #
    # Copy the +source+ directory to the +destination+.
    #
    # @param [String] source
    # @param [String] destination
    #
    def copy_directory(source, destination)
      FileUtils.cp_r(FileSyncer.glob("#{source}/*"), destination)
    end

    #
    # @!endgroup
    # --------------------------------------------------

    # Execute the command using shellout!
    #
    # @param [String] command
    def execute(command, options = {})
      options.merge! timeout: 3600, cwd: staging_dir
      shellout!(command,  options)
    end

    #
    # The list of files to exclude when syncing files. This comes from the list
    # of project exclusions and includes "common" SCM directories (like +.git+).
    #
    # @return [Array<String>]
    #
    def exclusions
      project.exclusions + %w(
        **/.git
        **/.hg
        **/.svn
        **/.gitkeep
      )
    end

    #
    # Execute this packager by running the following phases in order:
    #
    #   - setup
    #   - build
    #
    def run!
      # Ensure the package directory exists and is purged
      purge_directory(package_dir)

      # Run the setup and build sequences
      instance_eval(&self.class.setup) if self.class.setup
      instance_eval(&self.class.build) if self.class.build

      # Render the metadata
      render_metadata!

      # Ensure the temporary directory is removed at the end of a successful
      # run. Without removal, successful builds will "leak" in /tmp and cause
      # increased disk usage.
      #
      # Instead of having this as an +ensure+ block, failed builds will persist
      # this directory so developers can go poke around and figure out why the
      # build failed.
      remove_directory(staging_dir)
    end

    #
    # The path where the final packages will live on disk.
    #
    # @see {Config#package_dir}
    # @see {Config#project_root}
    #
    # @return [String]
    #
    def package_dir
      File.expand_path(Config.package_dir, Config.project_root)
    end

    #
    # The path to the staging dir on disk.
    #
    # @return [String]
    #
    def staging_dir
      @staging_dir ||= Dir.mktmpdir(project.name)
    end

    #
    # @!group Resource methods
    # --------------------------------------------------

    #
    # The preferred path to a resource on disk with the given +name+. This
    # method will perform an "intelligent" search for a resource by first
    # looking in the local project expected {#resources_path}, and then falling
    # back to Omnibus' files.
    #
    # @example When the resource exists locally
    #   resource_path("spec.erb") #=> "/path/to/project/resources/rpm/spec.erb"
    #
    # @example When the resource does not exist locally
    #   resource_path("spec.erb") #=> "/omnibus-x.y.z/resources/rpm/spec.erb"
    #
    # @param [String] name
    #   the name of the resource on disk to find
    #
    def resource_path(name)
      local = File.join(resources_path, name)

      if File.exist?(local)
        log.info(log_key) { "Using local resource `#{name}' from `#{local}'" }
        local
      else
        log.debug(log_key) { "Using vendored resource `#{name}'" }
        Omnibus.source_root.join("resources/#{id}/#{name}").to_s
      end
    end

    #
    # The path where this packager's resources reside on disk. This is the
    # given {Project#resources_path} combined with the packager's {#id}.
    #
    # @example RPM packager
    #   resources_path #=> "/path/to/project/resources/rpm"
    #
    # @return [String]
    #
    def resources_path
      File.expand_path("#{project.resources_path}/#{id}")
    end

    #
    # @!endgroup
    # --------------------------------------------------

    #
    # @!group Metadata methods
    # --------------------------------------------------

    #
    # Render the +metadata.json+ file inside the package directory. This method
    # is valled after the package has been built.
    #
    # @return [void]
    #
    def render_metadata!
      path = File.join(Config.package_dir, package_name)

      # If the package does not exist, something went wrong, and we should not
      # proceed any further.
      unless File.exist?(path)
        raise NoPackageFile.new(path)
      end

      Package::Metadata.generate(Package.new(path),
        name:             project.name,
        friendly_name:    project.friendly_name,
        homepage:         project.homepage,
        version:          project.build_version,
        iteration:        project.build_iteration,
      )
    end

    #
    # @!endgroup
    # --------------------------------------------------
  end
end
