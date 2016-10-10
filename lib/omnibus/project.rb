#
# Copyright 2012-2014 Chef Software, Inc.
# Copyright 2014 Noah Kantrowitz
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
require "ffi_yajl"
require "omnibus/manifest"
require "omnibus/manifest_entry"
require "omnibus/reports"

module Omnibus
  class Project
    class << self
      #
      # @param [String] name
      #   the name to the project definition to load from disk
      #
      # @return [Project]
      #
      def load(name, manifest = nil)
        loaded_projects[name] ||= begin
          filepath = Omnibus.project_path(name)

          if filepath.nil?
            raise MissingProject.new(name)
          else
            log.internal(log_key) do
              "Loading project `#{name}' from `#{filepath}'."
            end
          end

          instance = new(filepath, manifest)
          instance.evaluate_file(filepath)
          instance.load_dependencies
          instance
        end
      end

      #
      # Reset cached project information.
      #
      def reset!
        @loaded_projects = nil
      end

      private

      #
      # The list of projects loaded thus far.
      #
      # @return [Hash<String, Project>]
      #
      def loaded_projects
        @loaded_projects ||= {}
      end
    end

    attr_reader :manifest

    include Cleanroom
    include Digestable
    include Logging
    include NullArgumentable
    include Sugarable
    include Util

    def initialize(filepath = nil, manifest = nil)
      @filepath = filepath
      @manifest = manifest
    end

    #
    # @!group DSL methods
    #
    # The following DSL methods are available from within the project
    # definitions.
    # --------------------------------------------------

    #
    # **[Required]** Set or retrieve the name of the project.
    #
    # @example
    #   name 'chef'
    #
    # @raise [MissingRequiredAttribute] if a value was not set before being
    #   subsequently retrieved
    #
    # @param [String] val
    #   the name to set
    #
    # @return [String]
    #
    def name(val = NULL)
      if null?(val)
        @name || raise(MissingRequiredAttribute.new(self, :name, "hamlet"))
      else
        @name = val
      end
    end
    expose :name

    #
    # Set or retrieve a friendly name for the project. This defaults to the
    # capitalized name if not specified.
    #
    # @example
    #   friendly_name 'Chef'
    #
    # @param [String] val
    #   the name to set
    #
    # @return [String]
    #
    def friendly_name(val = NULL)
      if null?(val)
        @friendly_name || name.capitalize
      else
        @friendly_name = val
      end
    end
    expose :friendly_name

    #
    # Set or retrieve the package name of the project. Defaults to the package
    # name defaults to the project name.
    #
    # @example
    #   package_name 'com.chef.project'
    #
    # @param [String] val
    #   the package name to set
    #
    # @return [String]
    #
    def package_name(val = NULL)
      if null?(val)
        @package_name || name
      else
        @package_name = val
      end
    end
    expose :package_name

    #
    # **[Required]** Set or retrieve the path at which the project should be
    # installed by the generated package.
    #
    # Even on Windows-based systems, this path should be the Unix-like path,
    # since that's what Ruby expects. In the event +\+ is used as a file
    # separator, it will be replaced with +/+. This method also attempts to
    # remove duplicate slashes which might be caused as a result of string
    # interpolation.
    #
    # @example
    #   install_dir '/opt/chef'
    #
    # @raise [MissingRequiredAttribute] if a value was not set before being
    #   subsequently retrieved
    #
    # @param [String] val
    #   the install path to set
    #
    # @return [String]
    #
    def install_dir(val = NULL)
      if null?(val)
        @install_dir || raise(MissingRequiredAttribute.new(self, :install_dir, "/opt/chef"))
      else
        @install_dir = val.tr('\\', "/").squeeze("/").chomp("/")
      end
    end
    expose :install_dir

    #
    # The default root where a project should be installed. On Windows-based
    # systems, this value defaults to +C:+. On non-Windows systems, this value
    # defaults to +/opt+.
    #
    # @example
    #   install_dir "#{default_root}/chef" #=> Produces +C:/chef+ on Windows and
    #                                      #=> +/opt/chef+ on Linux
    #
    # @return [String]
    #
    def default_root
      if windows?
        "C:"
      else
        "/opt"
      end
    end
    expose :default_root

    #
    # Path to the +/files+ directory in the omnibus project. This directory can
    # contain arbitrary files used by the project.
    #
    # @example
    #   patch = File.join(files_path, 'rubygems', 'patch.rb')
    #
    # @return [String]
    #   path to the files directory
    #
    def files_path
      File.expand_path("#{Config.project_root}/files")
    end
    expose :files_path

    #
    # **[Required]** Set or retrieve the the package maintainer.
    #
    # @example
    #   maintainer 'Chef Software, Inc.'
    #
    # @raise [MissingRequiredAttribute] if a value was not set before being
    #   subsequently retrieved
    #
    # @param [String] val
    #   the name of the maintainer
    #
    # @return [String]
    #
    def maintainer(val = NULL)
      if null?(val)
        @maintainer || raise(MissingRequiredAttribute.new(self, :maintainer, "Chef Software, Inc."))
      else
        @maintainer = val
      end
    end
    expose :maintainer

    #
    # **[Required]** Set or retrive the package homepage.
    #
    # @example
    #   homepage 'https://www.getchef.com'
    #
    # @raise [MissingRequiredAttribute] if a value was not set before being
    #   subsequently retrieved
    #
    # @param [String] val
    #   the homepage for the project
    #
    # @return [String]
    #
    def homepage(val = NULL)
      if null?(val)
        @homepage || raise(MissingRequiredAttribute.new(self, :homepage, "https://www.getchef.com"))
      else
        @homepage = val
      end
    end
    expose :homepage

    #
    # Set or retrieve the project description.
    #
    # @example
    #   description 'This is my description'
    #
    # @param [String] val
    #   the project description
    #
    # @return [String]
    #
    def description(val = NULL)
      if null?(val)
        @description || "The full stack of #{name}"
      else
        @description = val
      end
    end
    expose :description

    #
    # Add to the list of packages this one provides.
    #
    # @example
    #   provide 'the-virtual-package'
    #
    # @param [String] val
    #   the name of the package to provide
    #
    # @return [String]
    #
    def provide(val = NULL)
      provides << val
      provides.dup
    end
    expose :provide

    #
    # Add to the list of packages this one replaces.
    #
    # This should only be used when renaming a package and obsoleting the old
    # name of the package. **Setting this to the same name as package_name will
    # cause RPM upgrades to fail.**
    #
    # @example
    #   replace 'the-old-package'
    #
    # @param [String] val
    #   the name of the package to replace
    #
    # @return [String]
    #
    def replace(val = NULL)
      replaces << val
      replaces.dup
    end
    expose :replace

    #
    # Add to the list of packages this one conflicts with.
    #
    # @example
    #   conflicts 'foo'
    #   conflicts 'bar'
    #
    # @param [String] val
    #   the conflict to add
    #
    # @return [Array<String>]
    #   the list of conflicts
    #
    def conflict(val)
      conflicts << val
      conflicts.dup
    end
    expose :conflict

    #
    # Set or retrieve the version of the project.
    #
    # @example Using a string
    #   build_version '1.0.0'
    #
    # @example From git
    #   build_version do
    #     source :git
    #   end
    #
    # @example From the version of a dependency
    #   build_version do
    #     source :version, from_dependency: 'chef'
    #   end
    #
    # @example From git of a dependency
    #   build_version do
    #     source :git, from_dependency: 'chef'
    #   end
    #
    # When using the +:git+ source, by default the output format of the
    # +build_version+ is semver. This can be modified using the +:output_format+
    # parameter to any of the methods of +BuildVersion+. For example:
    #
    #   build version do
    #     source :git, from_dependency: 'chef'
    #     output_format :git_describe
    #   end
    #
    # @see Omnibus::BuildVersion
    # @see Omnibus::BuildVersionDSL
    #
    # @param [String] val
    #   the build version to set
    # @param [Proc] block
    #   the block to run when constructing the +build_version+
    #
    # @return [String]
    #
    def build_version(val = NULL, &block)
      if block && !null?(val)
        raise Error, "You cannot specify additional parameters to " \
          "#build_version when a block is given!"
      end

      if block
        @build_version_dsl = BuildVersionDSL.new(&block)
      else
        if null?(val)
          @build_version_dsl.build_version
        else
          @build_version_dsl = BuildVersionDSL.new(val)
        end
      end
    end
    expose :build_version

    #
    # Set or retrieve the git revision of the omnibus
    # project being built.
    #
    # If not set by the user, and the current workding directory is a
    # git directory, it will return the revision of the current
    # working directory.
    #
    def build_git_revision(val = NULL)
      if null?(val)
        @build_git_revision ||= get_local_revision
      else
        @build_git_revision = val
      end
    end
    expose :build_git_revision

    #
    # Set or retrieve the build iteration of the project. Defaults to +1+ if not
    # otherwise set.
    #
    # @example
    #   build_iteration 5
    #
    # @param [Fixnum] val
    #   the build iteration number
    #
    # @return [Fixnum]
    #
    def build_iteration(val = NULL)
      if null?(val)
        @build_iteration || 1
      else
        @build_iteration = val
      end
    end
    expose :build_iteration

    #
    # Add or override a customization for the packager with the given +id+. When
    # given multiple blocks with the same +id+, they are evaluated _in order_,
    # so the last block evaluated will take precedence over the previous ones.
    #
    # @example
    #   package :id do
    #     key 'value'
    #   end
    #
    # @param [Symbol] id
    #   the id of the packager to customize
    #
    def package(id, &block)
      unless block
        raise InvalidValue.new(:package, "have a block")
      end

      packagers[id] << block
    end
    expose :package

    #
    # Add or override a customization for the compressor with the given +id+.
    # When given multiple blocks with the same +id+, they are evaluated
    # _in order_, so the last block evaluated will take precedence over the
    # previous ones.
    #
    # @example With customization
    #   compress :dmg do
    #     window_bounds '10, 20, 30, 40'
    #   end
    #
    # @example Without customization
    #   compress :tgz
    #
    # If multiple +compress+ blocks are specified, the "most prefered" one for
    # the current system will be used.
    #
    # @param [Symbol] id
    #   the id of the compressor to customize
    #
    def compress(id, &block)
      if block
        compressors[id] << block
      else
        compressors[id] << Proc.new {}
      end
    end
    expose :compress

    #
    # Set or retrieve the user the package should install as. This varies with
    # operating system, and may be ignored if the underlying packager does not
    # support it.
    #
    # Defaults to +"root"+.
    #
    # @example
    #   package_user 'build'
    #
    # @param [String] val
    #   the user to use for the package build
    #
    # @return [String]
    #
    def package_user(val = NULL)
      if null?(val)
        @package_user || "root"
      else
        @package_user = val
      end
    end
    expose :package_user

    #
    # Set or retrieve the overrides hash for one piece of software being
    # overridden. Calling it as a setter does not merge hash entries and it will
    # set all the overrides for a given software definition.
    #
    # @example
    #   override 'chef', version: '1.2.3'
    #
    # @param [Hash] val
    #   the value to override
    #
    # @return [Hash]
    #
    def override(name, val = NULL)
      if null?(val)
        overrides[name.to_sym]
      else
        overrides[name.to_sym] = val
      end
    end
    expose :override

    #
    # Set or retrieve the group the package should install as. This varies with
    # operating system and may  be ignored if the underlying packager does not
    # support it.
    #
    # Defaults to +Ohai['root_group']+. If +Ohai['root_group']+ is +nil+, it
    # defaults to +"root"+.
    #
    # @example
    #   package_group 'build'
    #
    # @param [String] val
    #   the group to use for the package build
    #
    # @return [String]
    #
    def package_group(val = NULL)
      if null?(val)
        @package_group || Ohai["root_group"] || "root"
      else
        @package_group = val
      end
    end
    expose :package_group

    #
    # Set or retrieve the path to the resources on disk for use in packagers.
    #
    # @example
    #   resources_path '/path/to/resources'
    #
    # @param [String] val
    #   the path where resources live
    #
    # @return [String]
    #
    def resources_path(val = NULL)
      if null?(val)
        @resources_path || "#{Config.project_root}/resources/#{name}"
      else
        @resources_path = File.expand_path(val)
      end
    end
    expose :resources_path

    #
    # The path to the package scripts directory for this project. These are
    # optional scripts that can be bundled into the resulting package for
    # running at various points in the package management lifecycle.
    #
    # These scripts and their names vary with operating system.
    #
    # @return [String]
    #
    def package_scripts_path(arg = NULL)
      if null?(arg)
        @package_scripts_path || "#{Config.project_root}/package-scripts/#{name}"
      else
        @package_scripts_path = File.expand_path(arg)
      end
    end
    expose :package_scripts_path

    #
    # Add a software dependency.
    #
    # Note that this is a *build time* dependency. If you need to specify an
    # external dependency that is required at runtime, see {#runtime_dependency}
    # instead.
    #
    # @example
    #   dependency 'foo'
    #   dependency 'bar'
    #
    # @param [String] val
    #   the name of a Software dependency
    #
    # @return [Array<String>]
    #   the list of dependencies
    #
    def dependency(val)
      dependencies << val
      dependencies.dup
    end
    expose :dependency

    #
    # Add a package that is a runtime dependency of this project.
    #
    # This is distinct from a build-time dependency, which should correspond to
    # a software definition.
    #
    # @example
    #   runtime_dependency 'foo'
    #
    # @param [String] val
    #   the name of the runtime dependency
    #
    # @return [Array<String>]
    #   the list of runtime dependencies
    #
    def runtime_dependency(val)
      runtime_dependencies << val
      runtime_dependencies.dup
    end
    expose :runtime_dependency

    #
    # Add a new exclusion pattern for a list of files or folders to exclude
    # when making the package.
    #
    # @example
    #   exclude '.git'
    #
    # @param [String] pattern
    #   the thing to exclude
    #
    # @return [Array<String>]
    #   the list of current exclusions
    #
    def exclude(pattern)
      exclusions << pattern
      exclusions.dup
    end
    expose :exclude

    #
    # Add a config file.
    #
    # @example
    #   config_file '/path/to/config.rb'
    #
    # @param [String] val
    #   the name of a config file of your software
    #
    # @return [Array<String>]
    #   the list of current config files
    #
    def config_file(val)
      config_files << val
      config_files.dup
    end
    expose :config_file

    #
    # Add other files or dirs outside of +install_dir+. These files retain their
    # relative paths inside the scratch directory:
    #
    #   /path/to/foo.txt #=> /tmp/package/path/to/foo.txt
    #
    #
    # @example
    #   extra_package_file '/path/to/file'
    #
    # @param [String] val
    #   the name of a dir or file to include in build
    #
    # @return [Array<String>]
    #   the list of current extra package files
    #
    def extra_package_file(val)
      extra_package_files << val
      extra_package_files.dup
    end
    expose :extra_package_file

    #
    # A proxy method to the underlying Ohai system.
    #
    # @example
    #   ohai['platform_family']
    #
    # @return [Ohai]
    #
    def ohai
      Ohai
    end
    expose :ohai

    #
    # Set or retrieve the {#license} of the project.
    #
    # @example
    #   license 'Apache 2.0'
    #
    # @param [String] val
    #   the license to set for the project.
    #
    # @return [String]
    #
    def license(val = NULL)
      if null?(val)
        @license || "Unspecified"
      else
        @license = val
      end
    end
    expose :license

    #
    # Set or retrieve the location of the {#license_file}
    # of the project.  It can either be a relative path inside
    # the project source directory or a URL.
    #
    #
    # @example
    #   license_file 'LICENSES/artistic.txt'
    #
    # @param [String] val
    #   the location of the license file for the project.
    #
    # @return [String]
    #
    def license_file(val = NULL)
      if null?(val)
        @license_file
      else
        @license_file = val
      end
    end
    expose :license_file

    #
    # Location of license file that omnibus will create and that will contain
    # the information about the license of the project plus the details about
    # the licenses of the software components included in the project.
    #
    # If no path is specified  install_dir/LICENSE is used.
    #
    # @example
    #   license_file_path
    #
    # @return [String]
    #
    def license_file_path(path = NULL)
      if null?(path)
        @license_file_path || File.join(install_dir, "LICENSE")
      else
        @license_file_path = File.join(install_dir, path)
      end
    end
    expose :license_file_path

    #
    # Location of json-formated version manifest, written at at the
    # end of the build. If no path is specified
    # +install_dir+/version-manifest.json is used.
    #
    # @example
    #   json_manifest_path
    #
    # @return [String]
    #
    def json_manifest_path(path = NULL)
      if null?(path)
        @json_manifest_path || File.join(install_dir, "version-manifest.json")
      else
        @json_manifest_path = path
      end
    end
    expose :json_manifest_path

    #
    # Location of text-formatted manifest.
    # (+install_dir+/version-manifest.txt if none is provided)
    #
    # This manifest uses the same format used by the
    # 'version-manifest' software definition in omnibus-software.
    #
    # @example
    #   text_manifest_path
    #
    # @return [String]
    #
    def text_manifest_path(path = NULL)
      if null?(path)
        @test_manifest_path || File.join(install_dir, "version-manifest.txt")
      else
        @text_manifest_path = path
      end
    end
    expose :text_manifest_path

    #
    # @!endgroup
    # --------------------------------------------------

    #
    # @!group Public API
    #
    # In addition to the DSL methods, the following methods are considered to
    # be the "public API" for a project.
    # --------------------------------------------------

    #
    # Recursively load all the dependencies for this project.
    #
    # @return [true]
    #
    def load_dependencies
      dependencies.each do |dependency|
        Software.load(self, dependency, manifest)
      end

      true
    end

    #
    # The list of software dependencies for this project. These is the software
    # that comprises your project, and is distinct from runtime dependencies.
    #
    # @see #dependency
    #
    # @param [Array<String>]
    #
    # @return [Array<String>]
    #
    def dependencies
      @dependencies ||= []
    end

    #
    # The path (on disk) where this project came from. Warning: this can be
    # +nil+ if a project was dynamically created!
    #
    # @return [String, nil]
    #
    def filepath
      @filepath
    end

    #
    #
    # The list of config files for this software.
    #
    # @return [Array<String>]
    #
    def config_files
      @config_files ||= []
    end

    #
    # The list of files and directories used to build this project.
    #
    # @return [Array<String>]
    #
    def extra_package_files(val = NULL)
      @extra_package_files ||= []
    end

    #
    # The list of software dependencies for this project.
    #
    # These is the software that is used at runtime for your project.
    #
    # @return [Array<String>]
    #
    def runtime_dependencies
      @runtime_dependencies ||= []
    end

    #
    # The list of things this project conflicts with.
    #
    # @return [Array<String>]
    #
    def conflicts
      @conflicts ||= []
    end

    #
    # The list of things this project replaces with.
    #
    # @return [Array<String>]
    #
    def replaces
      @replaces ||= []
    end

    #
    # The list of things this project provides.
    #
    # @return [Array<String>]
    #
    def provides
      @provides ||= []
    end

    #
    # The list of exclusions for this project.
    #
    # @return [Array<String>]
    #
    def exclusions
      @exclusions ||= []
    end

    #
    # Retrieve the list of overrides for all software being overridden.
    #
    # @return [Hash]
    #
    def overrides
      @overrides ||= {}
    end

    #
    # The list of packagers, in the following format:
    #
    #     {
    #       id: [#<Proc:0x001>, #<Proc:0x002>],
    #       # ...
    #     }
    #
    # @return [Hash<Symbol, Array<Proc>>]
    #   the packager blocks, indexed by key
    #
    def packagers
      @packagers ||= Hash.new { |h, k| h[k] = [] }
    end

    #
    # Instantiate new instances of the best packagers for this system.
    #
    # @return [[~Packager::Base]]
    #
    def packagers_for_system
      @packagers_for_system ||= Packager.for_current_system.map { |p| p.new(self) }
    end

    #
    # The list of compressors, in the following format:
    #
    #     {
    #       id: [#<Proc:0x001>, #<Proc:0x002>],
    #       # ...
    #     }
    #
    # @return [Hash<Symbol, Array<Proc>>]
    #   the compressor blocks, indexed by key
    #
    def compressors
      @compressors ||= Hash.new { |h, k| h[k] = [] }
    end

    #
    # Instantiate a new instance of the best compressor for this system.
    #
    # @return [~Compressor::Base]
    #
    def compressor
      @compressor ||= Compressor.for_current_system(compressors.keys).new(self)
    end

    #
    # The DSL for this build version.
    #
    # @return [BuildVersionDSL]
    #
    def build_version_dsl
      @build_version_dsl
    end

    #
    # Indicates whether the given  +software+ is defined as a software component
    # of this project.
    #
    # @param [String, Software] software
    #   the software or name of the software to find
    #
    # @return [true, false]
    #
    def dependency?(software)
      name = software.is_a?(Software) ? software.name : software
      dependencies.include?(name)
    end

    #
    # The library for this Omnibus project.
    #
    # @return [Library]
    #
    def library
      @library ||= Library.new(self)
    end

    #
    # Dirty the cache for this project. This can be called by other projects,
    # install path cache, or software definitions to invalidate the cache for
    # this project.
    #
    # @param [Software] software
    #   the software that dirtied the cache
    #
    # @return [true, false]
    #
    def dirty!(software)
      raise ProjectAlreadyDirty.new(self) if culprit
      @culprit = software
    end

    #
    # The software definition which dirtied this project.
    #
    # @return [Software, nil]
    #
    def culprit
      @culprit
    end

    #
    # Determine if the cache for this project is dirty.
    #
    # @return [true, false]
    #
    def dirty?
      !!culprit
    end

    #
    # Comparator for two projects (+name+)
    #
    # @return [1, 0, -1]
    #
    def <=>(other)
      self.name <=> other.name
    end

    #
    # Cache the build order so we don't re-compute
    #
    # @return [Array<Omnibus::Software>]
    #
    def softwares
      @softwares ||= library.build_order
    end

    #
    # Generate a version manifest of the loaded software sources.
    #
    # @returns [Omnibus::Manifest]
    #
    def built_manifest
      log.info(log_key) { "Building version manifest" }
      m = Omnibus::Manifest.new(build_version, build_git_revision, license)
      softwares.each do |software|
        m.add(software.name, software.manifest_entry)
      end
      m
    end

    def download
      ThreadPool.new(Config.workers) do |pool|
        softwares.each do |software|
          pool.schedule { software.fetch }
        end
      end
    end

    def build
      FileUtils.rm_rf(install_dir)
      FileUtils.mkdir_p(install_dir)

      Licensing.create_incrementally(self) do |license_collector|
        softwares.each do |software|
          software.build_me([license_collector])
        end
      end

      write_json_manifest
      write_text_manifest
      HealthCheck.run!(self)
      package_me
      compress_me
    end

    def write_json_manifest
      File.open(json_manifest_path, "w") do |f|
        f.write(FFI_Yajl::Encoder.encode(built_manifest.to_hash, pretty: true))
      end
    end

    #
    # Writes a text manifest to the text_manifest_path.  This uses the
    # same method as the "version-manifest" software definition in
    # omnibus-software.
    #
    def write_text_manifest
      File.open(text_manifest_path, "w") do |f|
        f.puts "#{name} #{build_version}"
        f.puts ""
        f.puts Omnibus::Reports.pretty_version_map(self)
      end
    end

    #
    # Download and build the project. Preserved for backwards
    # compatibility.
    #
    def build_me
      # Download all softwares in parallel
      download
      build
    end

    #
    #
    #
    def package_me
      destination = File.expand_path("pkg", Config.project_root)

      # Create the destination directory
      unless File.directory?(destination)
        FileUtils.mkdir_p(destination)
      end

      packagers_for_system.each do |packager|
        # Evaluate any packager-specific blocks, in order.
        packagers[packager.id].each do |block|
          packager.evaluate(&block)
        end

        # Run the actual packager
        packager.run!

        # Copy the generated package and metadata back into the workspace
        package_path = File.join(Config.package_dir, packager.package_name)
        FileUtils.cp(package_path, destination, preserve: true)
        FileUtils.cp("#{package_path}.metadata.json", destination, preserve: true)
      end
    end

    #
    #
    #
    def compress_me
      destination = File.expand_path("pkg", Config.project_root)

      # Create the destination directory
      unless File.directory?(destination)
        FileUtils.mkdir_p(destination)
      end

      # Evaluate any compressor-specific blocks, in order.
      compressors[compressor.id].each do |block|
        compressor.evaluate(&block)
      end

      # Run the actual compressor
      compressor.run!

      # Copy the compressed package and metadata back into the workspace, if it
      # exists
      package_path = File.join(Config.package_dir, compressor.package_name)

      if File.file?(package_path)
        FileUtils.cp(package_path, destination)
        FileUtils.cp("#{package_path}.metadata.json", destination)
      end
    end

    #
    # The unique "hash" for this project.
    #
    # @see (#shasum)
    #
    # @return [Fixnum]
    #
    def hash
      shasum.hash
    end

    #
    # Determine if two projects are identical.
    #
    # @param [Project] other
    #
    # @return [true, false]
    #
    def ==(other)
      self.hash == other.hash
    end
    alias_method :eql?, :==

    #
    # The unique SHA256 for this project.
    #
    # A project is defined by its name, its build_version, its install_dir,
    # and any overrides (as JSON). Additionally, if provided, the actual file
    # contents are included in the SHA to ensure uniqueness.
    #
    # @return [String]
    #
    def shasum
      @shasum ||= begin
        digest = Digest::SHA256.new

        update_with_string(digest, name)
        update_with_string(digest, install_dir)
        update_with_string(digest, FFI_Yajl::Encoder.encode(overrides))

        if filepath && File.exist?(filepath)
          update_with_file_contents(digest, filepath)
        else
          update_with_string(digest, "<DYNAMIC>")
        end

        digest.hexdigest
      end
    end

    #
    # @!endgroup
    # --------------------------------------------------

    private

    def get_local_revision
      GitRepository.new("./").revision
    rescue StandardError
      "unknown"
    end

    #
    # The log key for this project, overriden to include the name of the
    # project for build output.
    #
    # @return [String]
    #
    def log_key
      @log_key ||= "#{super}: #{name}"
    end
  end
end
