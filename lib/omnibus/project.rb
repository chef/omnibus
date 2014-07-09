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
      # @param [String] filepath
      #   the path to the project definition to load from disk
      #
      # @return [Software]
      #
      def load(filepath)
        instance = new
        instance.evaluate_file(filepath)
        instance
      end
    end

    include Cleanroom
    include Logging
    include NullArgumentable
    include Sugarable
    include Util

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
        @install_dir = windows_safe_path(val)
      end
    end
    expose :install_dir

    #
    # @deprecated Use {#install_dir} instead.
    #
    # @example (see #install_dir)
    # @raise (see #install_dir)
    # @param (see #install_dir)
    # @return (see #install_dir)
    #
    def install_path(val = NULL)
      log.deprecated(log_key) do
        "install_path (DSL). Please use install_dir instead."
      end

      install_dir(val)
    end
    expose :install_path

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
      "#{Config.project_root}/files"
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
    # Corresponds to the +--description+ flag of
    # {https://github.com/jordansissel/fpm fpm}.
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
    # Set or retrieve the name of the package this package will replace.
    #
    # Ultimately used as the value for the +--replaces+ flag in
    # {https://github.com/jordansissel/fpm fpm}.
    #
    # This should only be used when renaming a package and obsoleting the old
    # name of the package. Setting this to the same name as package_name will
    # cause RPM upgrades to fail.
    #
    # @example
    #   replace 'the-old-package'
    #
    # @param [String] val
    #   the name of the package to replace
    #
    # @return [String]
    #
    def replaces(val = NULL)
      if null?(val)
        @replaces
      else
        @replaces = val
      end
    end
    expose :replaces

    #
    # Add to the list of packages this one conflicts with.
    #
    # Specifying conflicts is optional.  See the +--conflicts+ flag in
    # {https://github.com/jordansissel/fpm fpm}.
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
    # Set or retrieve the +{deb/rpm/solaris}-user+ fpm argument.
    #
    # @example
    #   package_user 'build'
    #
    # @param [String] val
    #   the user to retrive for the fpm build
    #
    # @return [String]
    #
    def package_user(val = NULL)
      if null?(val)
        @package_user
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
    # Set or retrieve the +{deb/rpm/solaris}+-group fpm argument.
    #
    # @example
    #   package_group 'build'
    #
    # @param [String] val
    #   the group to retrive for the fpm build
    #
    # @return [String]
    #
    def package_group(val = NULL)
      if null?(val)
        @package_group
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
        @resources_path = val
      end
    end
    expose :resources_path

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
    # Corresponds to the +--depends+ flag of
    # {https://github.com/jordansissel/fpm fpm}.
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
    # Add a new exclusion pattern.
    #
    # Corresponds to the +--exclude+ flag of
    # {https://github.com/jordansissel/fpm fpm}.
    #
    # @example
    #   exclude 'foo'
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
    # Add other files or dirs outside of +install_dir+.
    #
    # @note This option is currently only supported with FPM based package
    # builds such as RPM, DEB and .sh (makeselfinst).  This is not supported
    # on Mac OSX packages, Windows MSI, AIX and Solaris
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
    # The platform version of the machine on which Omnibus is running, as
    # determined by Ohai.
    #
    # @deprecated Use +Ohai['platform_version']+ instead.
    #
    # @return [String]
    #
    def platform_version
      log.deprecated(log_key) do
        "platform_version (DSL). Please use Ohai['platform_version'] instead."
      end

      Ohai['platform_version']
    end
    expose :platform_version

    #
    # The platform of the machine on which Omnibus is running, as determined
    # by Ohai.
    #
    # @deprecated Use +Ohai['platform']+ instead.
    #
    # @return [String]
    #
    def platform
      log.deprecated(log_key) do
        "platform (DSL). Please use Ohai['platform'] instead."
      end

      Ohai['platform']
    end
    expose :platform

    #
    # The platform family of the machine on which Omnibus is running, as
    # determined by Ohai.
    #
    # @deprecated Use +Ohai['platform_family']+ instead.
    #
    # @return [String]
    #
    def platform_family
      log.deprecated(log_key) do
        "platform_family (DSL). Please use Ohai['platform_family'] instead."
      end

      Ohai['platform_family']
    end
    expose :platform_family

    #
    # The machine which this project is running on.
    #
    # @deprecated Use +Ohai['kernel']['machine']+ instead.
    #
    # @return [String]
    #
    def machine
      log.deprecated(log_key) do
        "machine (DSL). Please use Ohai['kernel']['machine'] instead."
      end

      Ohai['kernel']['machine']
    end
    expose :machine

    #
    # Convenience method for accessing the global Omnibus configuration object.
    #
    # @deprecated Use {Config} instead
    #
    # @return Config
    #
    # @see Config
    #
    def config
      log.deprecated(log_key) do
        'config (DSL). Please use Config.(thing) instead (capital C).'
      end

      Config
    end
    expose :config

    #
    # The list of software dependencies for this project. These is the software
    # that comprises your project, and is distinct from runtime dependencies.
    #
    # @deprecated Use {#dependency} instead (as a setter; the getter will stay)
    #
    # @todo Remove the "setter" part of this method and unexpose it as part of
    # the DSL in the next major release
    #
    # @see #dependency
    #
    # @param [Array<String>]
    #
    # @return [Array<String>]
    #
    def dependencies(*args)
      @dependencies ||= []

      # Handle the case where an array or list of args were given
      flattened_args = Array(args).flatten

      if flattened_args.empty?
        @dependencies
      else
        log.deprecated(log_key) do
          "dependencies (DSL). Please specify each dependency on its own " \
          "line like `dependency '#{Array(val).first}'`."
        end

        @dependencies = flattened_args
      end
    end
    expose :dependencies

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
      runtime_dependencies ||= []
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
    # All iteration strings begin with the value set in {#build_iteration}
    #
    # @return [String]
    def iteration
      case Ohai['platform_family']
      when 'rhel'
        Ohai['platform_version'] =~ /^(\d+)/
        maj = Regexp.last_match[1]
        "#{build_iteration}.el#{maj}"
      when 'freebsd'
        Ohai['platform_version'] =~ /^(\d+)/
        maj = Regexp.last_match[1]
        "#{build_iteration}.#{Ohai['platform']}.#{maj}.#{Ohai['kernel']['machine']}"
      when 'windows'
        "#{build_iteration}.windows"
      when 'aix', 'debian', 'mac_os_x'
        "#{build_iteration}"
      else
        "#{build_iteration}.#{Ohai['platform']}.#{Ohai['platform_version']}"
      end
    end

    #
    # The path to the package scripts directory for this project.
    # These are optional scripts that can be bundled into the
    # resulting package for running at various points in the package
    # management lifecycle.
    #
    # Currently supported scripts include:
    #
    # * postinst
    #
    #   A post-install script
    # * prerm
    #
    #   A pre-uninstall script
    # * postrm
    #
    #   A post-uninstall script
    #
    # Any scripts with these names that are present in the package
    # scripts directory will be incorporated into the package that is
    # built.  This only applies to fpm-built packages.
    #
    # Additionally, there may be a +makeselfinst+ script.
    #
    # @return [String]
    #
    # @todo This documentation really should be up at a higher level,
    #   particularly since the user has no way to change the path.
    #
    def package_scripts_path
      "#{Config.project_root}/package-scripts/#{name}"
    end

    def build_me
      FileUtils.mkdir_p(Config.package_dir)
      FileUtils.rm_rf(install_dir)
      FileUtils.mkdir_p(install_dir)

      library.build_order.each do |software|
        software.build_me
      end
      health_check_me
      package_me
    end

    def health_check_me
      if Ohai['platform'] == 'windows'
        log.info(log_key) { 'Skipping health check on Windows' }
      else
        # build a list of all whitelist files from all project dependencies
        whitelist_files = library.components.map { |component| component.whitelist_files }.flatten
        Omnibus::HealthCheck.run(install_dir, whitelist_files)
      end
    end

    def package_me
      destination = File.expand_path('pkg', Config.project_root)

      # Create the destination directory
      unless File.directory?(destination)
        FileUtils.mkdir_p(destination)
      end

      package_types.each do |pkg_type|
        if pkg_type == 'makeself'
          run_makeself
        elsif pkg_type == 'msi'
          run_msi
        elsif pkg_type == 'bff'
          run_bff
        elsif pkg_type == 'pkgmk'
          run_pkgmk
        elsif pkg_type == 'mac_pkg'
          run_mac_package_build
        elsif pkg_type == 'mac_dmg'
          # noop, since the dmg creation is handled by the packager
        else # pkg_type == "fpm"
          run_fpm(pkg_type)
        end

        render_metadata(pkg_type)

        if Ohai['platform'] == 'windows'
          FileUtils.cp(Dir["#{Config.package_dir}/*.msi*"], destination)
        elsif Ohai['platform'] == 'aix'
          FileUtils.cp(Dir["#{Config.package_dir}/*.bff*"], destination)
        else
          FileUtils.cp(Dir["#{Config.package_dir}/*"], destination)
        end
      end
    end

    # Ensures that certain project information has been set
    #
    # @todo raise MissingProjectConfiguration instead of printing the warning
    #   in the next major release
    #
    # @return [void]
    def validate
      name && install_dir && maintainer && homepage
      if package_name == replaces
        log.warn { BadReplacesLine.new.message }
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
        %w(pkgmk)
      when 'windows'
        %w(msi)
      when 'mac_os_x'
        %w(mac_pkg mac_dmg)
      else
        %w(makeself)
      end
    end

    #
    # Platform version to be used in package metadata. For rhel, the minor
    # version is removed, e.g., "5.6" becomes "5". For all other platforms,
    # this is just the platform_version.
    #
    # @return [String]
    #   the platform version
    #
    def platform_version_for_package
      case Ohai['platform_family']
      when 'debian', 'fedora', 'freebsd', 'rhel'
        if Ohai['platform'] == 'ubuntu'
          # Only want MAJOR.MINOR (Ubuntu 12.04)
          Ohai['platform_version'].split('.')[0..1].join('.')
        else
          # Only want MAJOR (Debian 7)
          Ohai['platform_version'].split('.').first
        end
      when 'aix', 'arch', 'gentoo', 'mac_os_x', 'openbsd', 'slackware', 'solaris2', 'suse'
        # Only want MAJOR.MINOR
        Ohai['platform_version'].split('.')[0..1].join('.')
      when 'omnios', 'smartos'
        # Only want MAJOR
        Ohai['platform_version'].split('.').first
      when 'windows'
        # Windows has this really awesome "feature", where their version numbers
        # internally do not match the "marketing" name. Dear Microsoft, this is
        # why we cannot have nice things.
        case Ohai['platform_version']
        when '6.1.7600' then '7'
        when '6.1.7601' then '2008r2'
        when '6.2.9200' then '8'
        when '6.3.9200' then '8.1'
        else
          raise UnknownPlatformVersion.new(Ohai['platform'], Ohai['platform_version'])
        end
      else
        raise UnknownPlatformFamily.new(Ohai['platform_family'])
      end
    end

    #
    # Platform name to be used when creating metadata for the artifact.
    # rhel/centos become "el", all others are just platform
    #
    # @return [String]
    #   the platform family short name
    #
    def platform_shortname
      if Ohai['platform_family'] == 'rhel'
        'el'
      else
        Ohai['platform']
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
        platform:         platform_shortname,
        platform_version: platform_version_for_package,
        arch:             Ohai['kernel']['machine'],
        version:          build_version,
      )
    end

    # The basename of the resulting package file.
    # @return [String] the basename of the package file
    def output_package(pkg_type)
      case pkg_type
      when 'makeself'
        "#{package_name}-#{build_version}_#{iteration}.sh"
      when 'msi'
        Packager::WindowsMsi.new(self).package_name
      when 'bff'
        "#{package_name}.#{bff_version}.bff"
      when 'pkgmk'
        "#{package_name}-#{build_version}-#{iteration}.solaris"
      when 'mac_pkg'
        Packager::MacPkg.new(self).package_name
      when 'mac_dmg'
        pkg = Packager::MacPkg.new(self)
        Packager::MacDmg.new(pkg).package_name
      else # fpm
        require "fpm/package/#{pkg_type}"
        pkg = FPM::Package.types[pkg_type].new
        pkg.version = build_version
        pkg.name = package_name
        pkg.iteration = iteration
        if pkg_type == 'solaris'
          pkg.to_s('NAME.FULLVERSION.ARCH.TYPE')
        else
          pkg.to_s
        end
      end
    end

    def bff_command
      bff_command = ['sudo /usr/sbin/mkinstallp -d / -T /tmp/bff/gen.template']
      [bff_command.join(' '), { returns: [0] }]
    end

    # The {https://github.com/jordansissel/fpm fpm} command to
    # generate a package for RedHat, Ubuntu, Solaris, etc. platforms.
    #
    # Does not execute the command, only assembles it.
    #
    # @return [Array<String>] the components of the fpm command; need
    #   to be joined with " " first.
    #
    # @todo Just make this return a String instead of an Array
    # @todo Use the long option names (i.e., the double-dash ones) in
    #   the fpm command for maximum clarity.
    def fpm_command(pkg_type)
      command_and_opts = [
        'fpm',
        '-s dir',
        "-t #{pkg_type}",
        "-v #{build_version}",
        "-n #{package_name}",
        "-p #{output_package(pkg_type)}",
        "--iteration #{iteration}",
        "-m '#{maintainer}'",
        "--description '#{description}'",
        "--url #{homepage}",
      ]

      if File.exist?(File.join(package_scripts_path, 'preinst'))
        command_and_opts << "--before-install '#{File.join(package_scripts_path, "preinst")}'"
      end

      if File.exist?("#{package_scripts_path}/postinst")
        command_and_opts << "--after-install '#{File.join(package_scripts_path, "postinst")}'"
      end
      # solaris packages don't support --pre-uninstall
      if File.exist?("#{package_scripts_path}/prerm")
        command_and_opts << "--before-remove '#{File.join(package_scripts_path, "prerm")}'"
      end
      # solaris packages don't support --post-uninstall
      if File.exist?("#{package_scripts_path}/postrm")
        command_and_opts << "--after-remove '#{File.join(package_scripts_path, "postrm")}'"
      end

      exclusions.each do |pattern|
        command_and_opts << "--exclude '#{pattern}'"
      end

      config_files.each do |config_file|
        command_and_opts << "--config-files '#{config_file}'"
      end

      runtime_dependencies.each do |runtime_dep|
        command_and_opts << "--depends '#{runtime_dep}'"
      end

      conflicts.each do |conflict|
        command_and_opts << "--conflicts '#{conflict}'"
      end

      if package_user
        %w(deb rpm solaris).each do |type|
          command_and_opts << " --#{type}-user #{package_user}"
        end
      end

      if package_group
        %w(deb rpm solaris).each do |type|
          command_and_opts << " --#{type}-group #{package_group}"
        end
      end

      command_and_opts << " --replaces #{replaces}" if replaces

      # All project files must be appended to the command "last", but before
      # the final install path
      extra_package_files.each do |files|
        command_and_opts << files
      end

      # Install path must be the final entry in the command
      command_and_opts << install_dir
      command_and_opts
    end

    # TODO: what's this do?
    def makeself_command
      command_and_opts = [
        Omnibus.source_root.join('bin', 'makeself.sh'),
        '--gzip',
        install_dir,
        output_package('makeself'),
        "'The full stack of #{@name}'",
      ]
      command_and_opts << './makeselfinst' if File.exist?("#{package_scripts_path}/makeselfinst")
      command_and_opts
    end

    # Runs the makeself commands to make a self extracting archive package.
    # As a (necessary) side-effect, sets
    # @return void
    def run_makeself
      package_commands = []
      # copy the makeself installer into package
      if File.exist?("#{package_scripts_path}/makeselfinst")
        package_commands << "cp #{package_scripts_path}/makeselfinst #{install_dir}/"
      end

      # run the makeself program
      package_commands << makeself_command.join(' ')

      # rm the makeself installer (for incremental builds)
      package_commands << "rm -f #{install_dir}/makeselfinst"
      package_commands.each { |cmd| run_package_command(cmd) }
    end

    # Runs the necessary command to make an MSI. As a side-effect, sets +output_package+
    # @return void
    def run_msi
      Packager::WindowsMsi.new(self).run!
    end

    def bff_version
      build_version.split(/[^\d]/)[0..2].join('.') + ".#{iteration}"
    end

    def run_bff
      FileUtils.rm_rf '/.info/*'
      FileUtils.rm_rf '/tmp/bff'
      FileUtils.mkdir '/tmp/bff'

      system "find #{install_dir} -print > /tmp/bff/file.list"

      system "cat #{package_scripts_path}/aix/opscode.chef.client.template | sed -e 's/TBS/#{bff_version}/' > /tmp/bff/gen.preamble"

      # @todo can we just use an erb template here?
      system "cat /tmp/bff/gen.preamble /tmp/bff/file.list #{package_scripts_path}/aix/opscode.chef.client.template.last > /tmp/bff/gen.template"

      FileUtils.cp "#{package_scripts_path}/aix/unpostinstall.sh", "#{install_dir}/bin"
      FileUtils.cp "#{package_scripts_path}/aix/postinstall.sh", "#{install_dir}/bin"

      run_package_command(bff_command)

      FileUtils.cp "/tmp/chef.#{bff_version}.bff", "/var/cache/omnibus/pkg/chef.#{bff_version}.bff"
    end

    def pkgmk_version
      "#{build_version}-#{iteration}"
    end

    def run_pkgmk
      install_dirname = File.dirname(install_dir)
      install_basename = File.basename(install_dir)

      system 'sudo rm -rf /tmp/pkgmk'
      FileUtils.mkdir '/tmp/pkgmk'

      system "cd #{install_dirname} && find #{install_basename} -print > /tmp/pkgmk/files"

      prototype_content = <<-EOF
i pkginfo
i postinstall
i postremove
      EOF

      File.open '/tmp/pkgmk/Prototype', 'w+' do |f|
        f.write prototype_content
      end

      # generate the prototype's file list
      system "cd #{install_dirname} && pkgproto < /tmp/pkgmk/files > /tmp/pkgmk/Prototype.files"

      # fix up the user and group in the file list to root
      system "awk '{ $5 = \"root\"; $6 = \"root\"; print }' < /tmp/pkgmk/Prototype.files >> /tmp/pkgmk/Prototype"

      pkginfo_content = <<-EOF
CLASSES=none
TZ=PST
PATH=/sbin:/usr/sbin:/usr/bin:/usr/sadm/install/bin
BASEDIR=#{install_dirname}
PKG=#{package_name}
NAME=#{package_name}
ARCH=#{`uname -p`.chomp}
VERSION=#{pkgmk_version}
CATEGORY=application
DESC=#{description}
VENDOR=#{maintainer}
EMAIL=#{maintainer}
PSTAMP=#{`hostname`.chomp + Time.now.utc.iso8601}
      EOF

      File.open '/tmp/pkgmk/pkginfo', 'w+' do |f|
        f.write pkginfo_content
      end

      FileUtils.cp "#{package_scripts_path}/postinst", '/tmp/pkgmk/postinstall'
      FileUtils.cp "#{package_scripts_path}/postrm", '/tmp/pkgmk/postremove'

      shellout!("pkgmk -o -r #{install_dirname} -d /tmp/pkgmk -f /tmp/pkgmk/Prototype")

      system 'pkgchk -vd /tmp/pkgmk chef'

      system "pkgtrans /tmp/pkgmk /var/cache/omnibus/pkg/#{output_package("pkgmk")} chef"
    end

    def run_mac_package_build
      Packager::MacPkg.new(self).run!
    end

    # Runs the necessary command to make a package with fpm. As a side-effect,
    # sets +output_package+
    # @return void
    def run_fpm(pkg_type)
      run_package_command(fpm_command(pkg_type).join(' '))
    end

    # Executes the given command via mixlib-shellout.
    # @return [Mixlib::ShellOut] returns the underlying Mixlib::ShellOut
    #   object, so the caller can inspect the stdout and stderr.
    def run_package_command(cmd)
      if cmd.is_a?(Array)
        command = cmd[0]
        cmd_options.merge!(cmd[1])
      else
        command = cmd
      end

      shellout!(command, cwd: Config.package_dir)
    end

    def log_key
      @log_key ||= "#{super}: #{name}"
    end
  end
end
