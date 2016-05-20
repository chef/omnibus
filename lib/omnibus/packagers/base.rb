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

require "fileutils"

module Omnibus
  class Packager::Base
    include Cleanroom
    include Digestable
    include Instrumentation
    include Logging
    include NullArgumentable
    include Sugarable
    include Templating
    include Util

    # The {Project} instance that we are packaging
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
        block ? @setup = block : @setup
      end

      # The commands/steps to build the package.
      def build(&block)
        block ? @build = block : @build
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
    # The ending name of this package on disk. This method is used to generate
    # metadata about the package after it is built.
    #
    # @abstract
    #
    # @return [String]
    #
    def package_name
      raise NotImplementedError
    end

    #
    # The list of files to exclude when syncing files. This comes from the list
    # of project exclusions and includes "common" SCM directories (like +.git+).
    #
    # @return [Array<String>]
    #
    def exclusions
      project.exclusions + %w{
        **/.git
        **/.hg
        **/.svn
        **/.gitkeep
      }
    end

    #
    # @!group DSL methods
    # --------------------------------------------------

    #
    # Retrieve the path at which the project will be installed by the
    # generated package.
    #
    # @return [String]
    #
    def install_dir
      project.install_dir
    end
    expose :install_dir

    #
    # (see Util#windows_safe_path)
    #
    expose :windows_safe_path

    #
    # @!endgroup
    # --------------------------------------------------

    #
    # Execute this packager by running the following phases in order:
    #
    #   - setup
    #   - build
    #
    def run!
      # Ensure the package directory exists
      create_directory(Config.package_dir)

      measure("Packaging time") do
        # Run the setup and build sequences
        instance_eval(&self.class.setup) if self.class.setup
        instance_eval(&self.class.build) if self.class.build

        # Render the metadata
        Metadata.generate(package_path, project)

        # Ensure the temporary directory is removed at the end of a successful
        # run. Without removal, successful builds will "leak" in /tmp and cause
        # increased disk usage.
        #
        # Instead of having this as an +ensure+ block, failed builds will persist
        # this directory so developers can go poke around and figure out why the
        # build failed.
        remove_directory(staging_dir)
      end
    end

    #
    # The path to the rendered package on disk. This is calculated by
    # combining the {Config#package_dir} with the name of the package, as
    # calculated by one of the subclasses.
    #
    # @return [String]
    #
    def package_path
      File.expand_path(File.join(Config.package_dir, package_name))
    end

    #
    # The path to the staging dir on disk.
    #
    # @return [String]
    #
    def staging_dir
      @staging_dir ||= Dir.mktmpdir(project.package_name)
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
  end
end
