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

require 'time'
require 'json'

module Omnibus
  #
  # Omnibus project DSL reader
  #
  # @todo It seems like there's a bit of a conflation between a "project" and a
  #   "package" in this class... perhaps the package-building portions should be
  #   extracted to a separate class.
  #
  #
  class Project
    class << self
      #
      # @param [String] name
      #   the name to the project definition to load from disk
      #
      # @return [Project]
      #
      def load(name)
        loaded_projects[name] ||= begin
          filepath = Omnibus.project_path(name)

          if filepath.nil?
            raise MissingProject.new(name)
          else
            log.debug(log_key) do
              "Loading project `#{name}' from `#{filepath}'."
            end
          end

          instance = new(filepath)
          instance.evaluate_file(filepath)
          instance.load_dependencies
          instance
        end
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

    include Cleanroom
    include Digestable
    include Logging
    include NullArgumentable
    include Sugarable
    include Util

    def initialize(filepath = nil)
      @filepath = filepath
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
    # @raise [MissingProjectConfiguration] if a value was not set before being
    #   subsequently retrieved
    #
    # @param [String] val
    #   the name to set
    #
    # @return [String]
    #
    def name(val = NULL)
      if null?(val)
        @name || raise(MissingProjectConfiguration.new('name', 'my_project'))
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
    # Set or retrieve the custom msi building parameters
    #
    # @example Using a hash
    #   msi_parameters upgrade_code: 'ABCD-1234'
    #
    # @example Using a block
    #   msi_parameters do
    #     # some complex operation
    #     { key: value }
    #   end
    #
    # @param [Hash] val
    #   the parameters to set
    # @param [Proc] block
    #   block to run when building the msi that returns a hash
    #
    # @return [Hash]
    #
    def msi_parameters(val = NULL, &block)
      if block && !null?(val)
        raise Error, 'You cannot specify additional parameters to ' \
          '#msi_parameters when a block is given!'
      end

      if block
        @msi_parameters = block
      else
        if null?(val)
          if @msi_parameters.is_a?(Proc)
            @msi_parameters.call
          else
            @msi_parameters ||= {}
          end
        else
          @msi_parameters = val
        end
      end
    end
    expose :msi_parameters

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
    # @example
    #   install_dir '/opt/chef'
    #
    # @raise [MissingProjectConfiguration] if a value was not set before being
    #   subsequently retrieved
    #
    # @param [String] val
    #   the install path to set
    #
    # @return [String]
    #
    def install_dir(val = NULL)
      if null?(val)
        @install_dir || raise(MissingProjectConfiguration.new('install_dir', '/opt/chef'))
      else
        @install_dir = File.expand_path(val, Config.project_root)
      end
    end
    expose :install_dir

    #
    # Path to the +/files+ directory in the omnibus project. This directory can
    # contain assets used for creating packages (e.g., Mac .pkg files and
    # Windows MSIs can be installed by GUI which can optionally be customized
    # with background images, license agreements, etc.)
    #
    # This method delegates to the {Config.project_root} module function so that
    # Packagers classes rely only on the Project object for their inputs.
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
    # @raise [MissingProjectConfiguration] if a value was not set before being
    #   subsequently retrieved
    #
    # @param [String] val
    #   the name of the maintainer
    #
    # @return [String]
    #
    def maintainer(val = NULL)
      if null?(val)
        @maintainer || raise(MissingProjectConfiguration.new('maintainer', 'Chef Software, Inc.'))
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
    # @raise [MissingProjectConfiguration] if a value was not set before being
    #   subsequently retrieved
    #
    # @param [String] val
    #   the homepage for the project
    #
    # @return [String]
    #
    def homepage(val = NULL)
      if null?(val)
        @homepage || raise(MissingProjectConfiguration.new('homepage', 'http://www.getchef.com'))
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
        @description ||= "The full stack of #{name}"
      else
        @description = val
      end
    end
    expose :description

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
        raise Error, 'You cannot specify additional parameters to ' \
          '#build_version when a block is given!'
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
        @build_iteration ||= 1
      else
        @build_iteration = val
      end
    end
    expose :build_iteration

    #
    # The identifer for the mac package.
    #
    # @example
    #   mac_pkg_identifier 'com.getchef.chefdk'
    #
    # @param [String] val
    #   the package identifier
    #
    # @return [String]
    #
    def mac_pkg_identifier(val = NULL)
      if null?(val)
        @mac_pkg_identifier
      else
        @mac_pkg_identifier = val
      end
    end
    expose :mac_pkg_identifier

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
        @package_user || 'root'
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
        overrides[name]
      else
        overrides[name] = val
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
        @package_group || Ohai['root_group'] || 'root'
      else
        @package_group = val
      end
    end
    expose :package_group

    #
    # Set or retrieve the resources path to be used by packagers.
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
        @resources_path
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
    # @!endgroup
    # --------------------------------------------------

    #
    # @!group Public API
    #
    # In addition to the DSL methods, the following methods are considered to
    # be the "public API" for a project.
    # --------------------------------------------------

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
        Software.load(self, dependency)
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
    # @return [true, false]
    #
    def dirty!
      @dirty = true
    end

    #
    # Determine if the cache for this project is dirty.
    #
    # @return [true, false]
    #
    def dirty?
      !!@dirty
    end

    #
    # Comparator for two projects (+name+)
    #
    # @return [1, 0, -1]
    #
    def <=>(other)
      self.name <=> other.name
    end

    # Defines the iteration for the package to be generated.  Adheres
    # to the conventions of the platform for which the package is
    # being built.
    #
    # @deprecated Use +build_iteration+ instead.
    #
    # @return [String] build_iteration
    #
    def iteration
      log.deprecated(log_key) do
        "iteration (DSL). Please use build_iteration instead."
      end

      build_iteration
    end

    def build_me
      FileUtils.rm_rf(install_dir)
      FileUtils.mkdir_p(install_dir)

      # Cache the build order so we don't re-compute
      softwares = library.build_order

      # Download all softwares first
      softwares.each do |software|
        software.fetch
      end

      # Now build each software
      softwares.each do |software|
        software.build_me
      end

      # Health check
      HealthCheck.run!(self)

      # Package
      package_me
    end

    def package_me
      destination = File.expand_path('pkg', Config.project_root)

      # Create the destination directory
      unless File.directory?(destination)
        FileUtils.mkdir_p(destination)
      end

      package_types.each do |pkg_type|
        if pkg_type == 'makeself'
          Packger::Makeself.new(self).run!
        elsif pkg_type == 'msi'
          Packager::MSI.new(self).run!
        elsif pkg_type == 'bff'
          Packager::BFF.new(self).run!
        elsif pkg_type == 'solaris'
          Packager::Solaris.new(self).run!
        elsif pkg_type == 'pkg'
          Packager::PKG.new(self).run!
        elsif pkg_type == 'mac_dmg'
          # noop, since the dmg creation is handled by the packager
        elsif pkg_type == 'rpm'
          Packager::RPM.new(self).run!
        elsif pkg_type == 'deb'
          Packager::DEB.new(self).run!
        else
          raise RuntimeError, "I do not know how to package a `#{pkg_type}'!"
        end

        render_metadata(pkg_type)

        if Ohai['platform'] == 'windows'
          FileUtils.cp(FileSyncer.glob("#{Config.package_dir}/*.msi*"), destination)
        elsif Ohai['platform'] == 'aix'
          FileUtils.cp(FileSyncer.glob("#{Config.package_dir}/*.bff*"), destination)
        else
          FileUtils.cp(FileSyncer.glob("#{Config.package_dir}/*"), destination)
        end
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

        log.info(log_key)  { "Calculating shasum" }
        log.debug(log_key) { "name: #{name.inspect}" }
        log.debug(log_key) { "install_dir: #{install_dir.inspect}" }
        log.debug(log_key) { "overrides: #{overrides.inspect}" }

        update_with_string(digest, name)
        update_with_string(digest, install_dir)
        update_with_string(digest, JSON.fast_generate(overrides))

        if filepath && File.exist?(filepath)
          log.debug(log_key) { "filepath: #{filepath.inspect}" }
          update_with_file_contents(digest, filepath)
        else
          log.debug(log_key) { "filepath: <DYNAMIC>" }
          update_with_string(digest, '<DYNAMIC>')
        end

        shasum = digest.hexdigest

        log.debug(log_key) { "shasum: #{shasum.inspect}" }

        shasum
      end
    end

    #
    # @!endgroup
    # --------------------------------------------------

    private

    #
    # Determine the package type(s) to be built, based on the platform
    # family for which the package is being built.
    #
    # If specific types cannot be determined, default to +["makeself"]+.
    #
    # @return [Array<(String)>]
    #
    def package_types
      case Ohai['platform_family']
      when 'debian'
        %w(deb)
      when 'fedora', 'rhel'
        %w(rpm)
      when 'aix'
        %w(bff)
      when 'solaris2'
        %w(solaris)
      when 'windows'
        %w(msi)
      when 'mac_os_x'
        %w(pkg mac_dmg)
      else
        %w(makeself)
      end
    end

    def render_metadata(pkg_type)
      basename = output_package(pkg_type)
      pkg_path = "#{Config.package_dir}/#{basename}"

      # Don't generate metadata for packages that haven't been created.
      # TODO: Fix this and make it betterer
      return unless File.exist?(pkg_path)

      package = Package.new(pkg_path)
      Package::Metadata.generate(package,
        name:             name,
        friendly_name:    friendly_name,
        homepage:         homepage,
        version:          build_version,
        iteration:        build_iteration,
      )
    end

    # The basename of the resulting package file.
    # @return [String] the basename of the package file
    def output_package(pkg_type)
      case pkg_type
      when 'makeself'
        Packager::Makeself.new(self).package_name
      when 'msi'
        Packager::MSI.new(self).package_name
      when 'bff'
        Packger::Bff.new(self).package_name
      when 'solaris'
        Packager::Solaris.new(self).package_name
      when 'pkg'
        Packager::PKG.new(self).package_name
      when 'mac_dmg'
        pkg = Packager::PKG.new(self)
        Packager::MacDmg.new(pkg).package_name
      when 'rpm'
        Packager::RPM.new(self).package_name
      when 'deb'
        Packager::DEB.new(self).package_name
      else
        raise RuntimeError, "I do not know how to build a `#{pkg_type}'!"
      end
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
