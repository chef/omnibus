#
# Copyright:: Copyright (c) 2012-2014 Chef Software, Inc.
# Copyright:: Copyright (c) 2014 Noah Kantrowitz
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
require 'omnibus/artifact'
require 'omnibus/exceptions'
require 'omnibus/library'
require 'omnibus/util'
require 'omnibus/packagers/mac_pkg'
require 'time'

module Omnibus
  # Omnibus project DSL reader
  #
  # @todo It seems like there's a bit of a conflation between a
  #   "project" and a "package" in this class... perhaps the
  #   package-building portions should be extracted to a separate
  #   class.
  # @todo: Reorder DSL methods to fit in the same YARD group
  # @todo: Generate the DSL methods via metaprogramming... they're all so similar
  class Project
    include Rake::DSL
    include Util

    NULL_ARG = Object.new

    attr_reader :library

    # Convenience method to initialize a Project from a DSL file.
    #
    # @param filename [String] the filename of the Project DSL file to load.
    def self.load(filename)
      new(IO.read(filename), filename)
    end

    # Create a new Project from the contents of a DSL file.  Prefer
    # calling {Omnibus::Project#load} instead of using this method
    # directly.
    #
    # @param io [String] the contents of a Project DSL (_not_ the filename!)
    # @param filename [String] unused!
    #
    # @see Omnibus::Project#load
    def initialize(io, filename)
      @output_package = nil
      @name = nil
      @package_name = nil
      @install_path = nil
      @homepage = nil
      @description = nil
      @replaces = nil
      @mac_pkg_identifier = nil
      @overrides = {}

      @exclusions = []
      @conflicts = []
      @config_files = []
      @extra_package_files = []
      @dependencies = []
      @runtime_dependencies = []
      instance_eval(io, filename)
      validate

      @library = Omnibus::Library.new(self)
      render_tasks
    end

    # Ensures that certain project information has been set
    #
    # @raise [MissingProjectConfiguration] if a required parameter has
    #   not been set
    # @return [void]
    def validate
      name && install_path && maintainer && homepage
    end

    # @!group DSL methods
    # Here is some broad documentation for the DSL methods as a whole.

    # Set or retrieve the name of the project
    #
    # @param val [String] the name to set
    # @return [String]
    #
    # @raise [MissingProjectConfiguration] if a value was not set
    #   before being subsequently retrieved (i.e., a name
    #   must be set in order to build a project)
    def name(val = NULL_ARG)
      @name = val unless val.equal?(NULL_ARG)
      @name || fail(MissingProjectConfiguration.new('name', 'my_project'))
    end

    # Set or retrieve the package name of the project.  Unless
    # explicitly set, the package name defaults to the project name
    #
    # @param val [String] the package name to set
    # @return [String]
    def package_name(val = NULL_ARG)
      @package_name = val unless val.equal?(NULL_ARG)
      @package_name.nil? ? @name : @package_name
    end

    # Set or retrieve the path at which the project should be
    # installed by the generated package.
    #
    # @param val [String]
    # @return [String]
    #
    # @raise [MissingProjectConfiguration] if a value was not set
    #   before being subsequently retrieved (i.e., an install_path
    #   must be set in order to build a project)
    def install_path(val = NULL_ARG)
      @install_path = val unless val.equal?(NULL_ARG)
      @install_path || fail(MissingProjectConfiguration.new('install_path', '/opt/chef'))
    end

    # Set or retrieve the the package maintainer.
    #
    # @param val [String]
    # @return [String]
    #
    # @raise [MissingProjectConfiguration] if a value was not set
    #   before being subsequently retrieved (i.e., a maintainer must
    #   be set in order to build a project)
    def maintainer(val = NULL_ARG)
      @maintainer = val unless val.equal?(NULL_ARG)
      @maintainer || fail(MissingProjectConfiguration.new('maintainer', 'Chef Software, Inc.'))
    end

    # Set or retrive the package homepage.
    #
    # @param val [String]
    # @return [String]
    #
    # @raise [MissingProjectConfiguration] if a value was not set
    #   before being subsequently retrieved (i.e., a homepage must be
    #   set in order to build a project)
    def homepage(val = NULL_ARG)
      @homepage = val unless val.equal?(NULL_ARG)
      @homepage || fail(MissingProjectConfiguration.new('homepage', 'http://www.getchef.com'))
    end

    # Defines the iteration for the package to be generated.  Adheres
    # to the conventions of the platform for which the package is
    # being built.
    #
    # All iteration strings begin with the value set in {#build_iteration}
    #
    # @return [String]
    def iteration
      case platform_family
      when 'rhel'
        platform_version =~ /^(\d+)/
        maj = Regexp.last_match[1]
        "#{build_iteration}.el#{maj}"
      when 'freebsd'
        platform_version =~ /^(\d+)/
        maj = Regexp.last_match[1]
        "#{build_iteration}.#{platform}.#{maj}.#{machine}"
      when 'windows'
        "#{build_iteration}.windows"
      when 'aix', 'debian'
        "#{build_iteration}"
      else
        "#{build_iteration}.#{platform}.#{platform_version}"
      end
    end

    # Set or retrieve the project description.  Defaults to `"The full
    # stack of #{name}"`
    #
    # Corresponds to the `--description` flag of
    # {https://github.com/jordansissel/fpm fpm}.
    #
    # @param val [String] the project description
    # @return [String]
    #
    # @see #name
    def description(val = NULL_ARG)
      @description = val unless val.equal?(NULL_ARG)
      @description || "The full stack of #{name}"
    end

    # Set or retrieve the name of the package this package will replace.
    #
    # Ultimately used as the value for the `--replaces` flag in
    # {https://github.com/jordansissel/fpm fpm}.
    #
    # @param val [String] the name of the package to replace
    # @return [String]
    #
    # @todo Consider having this default to {#package_name}; many uses of this
    #   method effectively do this already.
    def replaces(val = NULL_ARG)
      @replaces = val unless val.equal?(NULL_ARG)
      @replaces
    end

    # Add to the list of packages this one conflicts with.
    #
    # Specifying conflicts is optional.  See the `--conflicts` flag in
    # {https://github.com/jordansissel/fpm fpm}.
    #
    # @param val [String]
    # @return [void]
    def conflict(val)
      @conflicts << val
    end

    # Set or retrieve the version of the project.
    #
    # @param val [String] the version to set
    # @return [String]
    #
    # @see Omnibus::BuildVersion
    def build_version(val = NULL_ARG)
      @build_version = val unless val.equal?(NULL_ARG)
      @build_version
    end

    # Set or retrieve the build iteration of the project.  Defaults to
    # `1` if not otherwise set.
    #
    # @param val [Fixnum]
    # @return [Fixnum]
    #
    # @todo Is there a better name for this than "build_iteration"?
    #   Would be nice to cut down confusiton with {#iteration}.
    def build_iteration(val = NULL_ARG)
      @build_iteration = val unless val.equal?(NULL_ARG)
      @build_iteration || 1
    end

    def mac_pkg_identifier(val = NULL_ARG)
      @mac_pkg_identifier = val unless val.equal?(NULL_ARG)
      @mac_pkg_identifier
    end

    # Set or retrieve the {deb/rpm/solaris}-user fpm argument.
    #
    # @param val [String]
    # @return [String]
    def package_user(val = NULL_ARG)
      @pkg_user = val unless val.equal?(NULL_ARG)
      @pkg_user
    end

    # Set or retrieve the full overrides hash for all software being overridden.  Calling it as
    # a setter does not merge hash entries and will obliterate any previous overrides that have been setup.
    #
    # @param val [Hash]
    # @return [Hash]
    def overrides(val = NULL_ARG)
      @overrides = val unless val.equal?(NULL_ARG)
      @overrides
    end

    # Set or retrieve the overrides hash for one piece of software being overridden.  Calling it as a
    # setter does not merge hash entries and it will set all the overrides for a given software definition.
    #
    # @param val [Hash]
    # @return [Hash]
    def override(name, val = NULL_ARG)
      @overrides[name] = val unless val.equal?(NULL_ARG)
      @overrides[name]
    end

    # Set or retrieve the {deb/rpm/solaris}-group fpm argument.
    #
    # @param val [String]
    # @return [String]
    def package_group(val = NULL_ARG)
      @pkg_group = val unless val.equal?(NULL_ARG)
      @pkg_group
    end

    # Add an Omnibus software dependency.
    #
    # Note that this is a *build time* dependency.  If you need to
    # specify an external dependency that is required at runtime, see
    # {#runtime_dependency} instead.
    #
    # @param val [String] the name of a Software dependency
    # @return [void]
    def dependency(val)
      @dependencies << val
    end

    # Add a package that is a runtime dependency of this
    # project.
    #
    # This is distinct from a build-time dependency, which should
    # correspond to an Omnibus software definition.
    #
    # Corresponds to the `--depends` flag of
    # {https://github.com/jordansissel/fpm fpm}.
    #
    # @param val [String] the name of the runtime dependency
    # @return [void]
    def runtime_dependency(val)
      @runtime_dependencies << val
    end

    # Set or retrieve the list of software dependencies for this
    # project.  As this is a DSL method, only pass the names of
    # software components, not {Omnibus::Software} objects.
    #
    # These is the software that comprises your project, and is
    # distinct from runtime dependencies.
    #
    # @note This will reinitialize the internal depdencies Array
    #   and overwrite any dependencies that may have been set using
    #   {#dependency}.
    #
    # @param val [Array<String>] a list of names of Software components
    # @return [Array<String>]
    def dependencies(val = NULL_ARG)
      @dependencies = val unless val.equal?(NULL_ARG)
      @dependencies
    end

    # Add a new exclusion pattern.
    #
    # Corresponds to the `--exclude` flag of {https://github.com/jordansissel/fpm fpm}.
    #
    # @param pattern [String]
    # @return void
    def exclude(pattern)
      @exclusions << pattern
    end

    # Add a config file.
    #
    # @param val [String] the name of a config file of your software
    # @return [void]
    def config_file(val)
      @config_files << val
    end

    # Add other files or dirs outside of install_path
    #
    # @param val [String] the name of a dir or file to include in build
    # @return [void]
    # NOTE: This option is currently only supported with FPM based package
    # builds such as RPM, DEB and .sh (makeselfinst).  This isn't supported
    # on Mac OSX packages, Windows MSI, AIX and Solaris
    def extra_package_file(val)
      @extra_package_files << val
    end

    # Set or retrieve the array of files and directories used to
    # build this project. If you use this to write, only pass the
    # full path to the dir or file you want included in the omnibus
    # package build.
    #
    # @note - similar to the depdencies array - this will reinitialize
    # the files array and overwrite and dependencies that were set using
    # {#file}.
    #
    # @param val [Array<String>] a list of names of Software components
    # @return [Array<String>]
    def extra_package_files(val = NULL_ARG)
      @extra_package_files = val unless val.equal?(NULL_ARG)
      @extra_package_files
    end

    # Returns the platform version of the machine on which Omnibus is
    # running, as determined by Ohai.
    #
    # @return [String]
    def platform_version
      OHAI.platform_version
    end

    # Returns the platform of the machine on which Omnibus is running,
    # as determined by Ohai.
    #
    # @return [String]
    def platform
      OHAI.platform
    end

    # Returns the platform family of the machine on which Omnibus is
    # running, as determined by Ohai.
    #
    # @return [String]
    def platform_family
      OHAI.platform_family
    end

    def machine
      OHAI['kernel']['machine']
    end

    # Convenience method for accessing the global Omnibus configuration object.
    #
    # @return Omnibus::Config
    #
    # @see Omnibus::Config
    def config
      Omnibus.config
    end

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
    # Additionally, there may be a `makeselfinst` script.
    #
    # @return [String]
    #
    # @todo This documentation really should be up at a higher level,
    #   particularly since the user has no way to change the path.
    def package_scripts_path
      "#{Omnibus.project_root}/package-scripts/#{name}"
    end

    # Path to the /files directory in the omnibus project. This directory can
    # contain assets used for creating packages (e.g., Mac .pkg files and
    # Windows MSIs can be installed by GUI which can optionally be customized
    # with background images, license agreements, etc.)
    #
    # This method delegates to the Omnibus.project_root module function so that
    # Packagers classes rely only on the Project object for their inputs.
    #
    # @return [String] path to the files directory.
    def files_path
      "#{Omnibus.project_root}/files"
    end

    # The directory where packages are written when created. Delegates to
    # #config. The delegation allows Packagers (like Packagers::MacPkg) to
    # define the implementation rather than using the global config everywhere.
    #
    # @return [String] path to the package directory.
    def package_dir
      config.package_dir
    end

    # The directory where intermediate packaging products may be stored.
    # Delegates to Config so that Packagers have a consistent API.
    #
    # @see Config.package_tmp some caveats.
    # @return [String] path to the package temp directory.
    def package_tmp
      config.package_tmp
    end

    # Determine the package type(s) to be built, based on the platform
    # family for which the package is being built.
    #
    # If specific types cannot be determined, default to `["makeself"]`.
    #
    # @return [Array<(String)>]
    #
    # @todo Why does this only ever return a single-element array,
    #   instead of just a string, or symbol?
    def package_types
      case platform_family
      when 'debian'
        ['deb']
      when 'fedora', 'rhel'
        ['rpm']
      when 'aix'
        ['bff']
      when 'solaris2'
        ['pkgmk']
      when 'windows'
        ['msi']
      when 'mac_os_x'
        ['mac_pkg']
      else
        ['makeself']
      end
    end

    # Indicates whether `software` is defined as a software component
    # of this project.
    #
    # @param software [String, Omnibus::Software, #name]
    # @return [Boolean]
    #
    # @see #dependencies
    def dependency?(software)
      name = if software.respond_to?(:name)
               software.send(:name)
             else
               software
             end
      @dependencies.include?(name)
    end

    # @!endgroup

    private

    # An Array of platform data suitable for `Artifact.new`. This will go into
    # metadata generated for the artifact, and be used for the file hierarchy
    # of released packages if the default release scripts are used.
    # @return [Array<String>] platform_shortname, platform_version_for_package,
    #   machine architecture.
    def platform_tuple
      [platform_shortname, platform_version_for_package, machine]
    end

    # Platform version to be used in package metadata. For rhel, the minor
    # version is removed, e.g., "5.6" becomes "5". For all other platforms,
    # this is just the platform_version.
    # @return [String] the platform version
    def platform_version_for_package
      if platform == 'rhel'
        platform_version[/([\d]+)\..+/, 1]
      else
        platform_version
      end
    end

    # Platform name to be used when creating metadata for the artifact.
    # rhel/centos become "el", all others are just platform
    # @return [String] the platform family short name
    def platform_shortname
      if platform_family == 'rhel'
        'el'
      else
        platform
      end
    end

    def render_metadata(pkg_type)
      basename = output_package(pkg_type)
      pkg_path = "#{config.package_dir}/#{basename}"
      artifact = Artifact.new(pkg_path, [platform_tuple], version: build_version)
      metadata = artifact.flat_metadata
      File.open("#{pkg_path}.metadata.json", 'w+') do |f|
        f.print(JSON.pretty_generate(metadata))
      end
    end

    # The basename of the resulting package file.
    # @return [String] the basename of the package file
    def output_package(pkg_type)
      case pkg_type
      when 'makeself'
        "#{package_name}-#{build_version}_#{iteration}.sh"
      when 'msi'
        "#{package_name}-#{build_version}-#{iteration}.msi"
      when 'bff'
        "#{package_name}.#{bff_version}.bff"
      when 'pkgmk'
        "#{package_name}-#{build_version}-#{iteration}.solaris"
      when 'mac_pkg'
        Packagers::MacPkg.new(self).package_name
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

    # The command to generate an MSI package on Windows platforms.
    #
    # Does not execute the command, only assembles it.
    #
    # @return [Array<(String, Hash)>] The complete MSI command, plus a
    #   Hash of options to be passed on to Mixlib::ShellOut
    #
    # @see Mixlib::ShellOut
    #
    # @todo For this and all the *_command methods, just return a
    #   Mixlib::ShellOut object ready for execution.  Using Arrays
    #   makes downstream processing needlessly complicated.
    def msi_command
      msi_command = [
        'light.exe',
        '-nologo',
        '-ext WixUIExtension',
        '-cultures:en-us',
        "-loc #{install_path}\\msi-tmp\\#{package_name}-en-us.wxl",
        "#{install_path}\\msi-tmp\\#{package_name}-Files.wixobj",
        "#{install_path}\\msi-tmp\\#{package_name}.wixobj",
        "-out #{config.package_dir}\\#{output_package("msi")}",
      ]

      # Don't care about the 204 return code from light.exe since it's
      # about some expected warnings...
      [msi_command.join(' '), { returns: [0, 204] }]
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
    # In contrast to {#msi_command}, command generated by
    # {#fpm_command} does not require any Mixlib::Shellout options.
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

      @exclusions.each do |pattern|
        command_and_opts << "--exclude '#{pattern}'"
      end

      @config_files.each do |config_file|
        command_and_opts << "--config-files '#{config_file}'"
      end

      @runtime_dependencies.each do |runtime_dep|
        command_and_opts << "--depends '#{runtime_dep}'"
      end

      @conflicts.each do |conflict|
        command_and_opts << "--conflicts '#{conflict}'"
      end

      if @pkg_user
        %w(deb rpm solaris).each do |type|
          command_and_opts << " --#{type}-user #{@pkg_user}"
        end
      end

      if @pkg_group
        %w(deb rpm solaris).each do |type|
          command_and_opts << " --#{type}-group #{@pkg_group}"
        end
      end

      command_and_opts << " --replaces #{@replaces}" if @replaces
      command_and_opts << install_path

      @extra_package_files.each do |files|
        command_and_opts << files
      end

      command_and_opts
    end

    # TODO: what's this do?
    def makeself_command
      command_and_opts = [
        File.expand_path(File.join(Omnibus.source_root, 'bin', 'makeself.sh')),
        '--gzip',
        install_path,
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
        package_commands << "cp #{package_scripts_path}/makeselfinst #{install_path}/"
      end

      # run the makeself program
      package_commands << makeself_command.join(' ')

      # rm the makeself installer (for incremental builds)
      package_commands << "rm -f #{install_path}/makeselfinst"
      package_commands.each { |cmd| run_package_command(cmd) }
    end

    # Runs the necessary command to make an MSI. As a side-effect, sets `output_package`
    # @return void
    def run_msi
      run_package_command(msi_command)
    end

    def bff_version
      build_version.split(/[^\d]/)[0..2].join('.') + ".#{iteration}"
    end

    def run_bff
      FileUtils.rm_rf '/.info/*'
      FileUtils.rm_rf '/tmp/bff'
      FileUtils.mkdir '/tmp/bff'

      system "find #{install_path} -print > /tmp/bff/file.list"

      system "cat #{package_scripts_path}/aix/opscode.chef.client.template | sed -e 's/TBS/#{bff_version}/' > /tmp/bff/gen.preamble"

      # @todo can we just use an erb template here?
      system "cat /tmp/bff/gen.preamble /tmp/bff/file.list #{package_scripts_path}/aix/opscode.chef.client.template.last > /tmp/bff/gen.template"

      FileUtils.cp "#{package_scripts_path}/aix/unpostinstall.sh", "#{install_path}/bin"
      FileUtils.cp "#{package_scripts_path}/aix/postinstall.sh", "#{install_path}/bin"

      run_package_command(bff_command)

      FileUtils.cp "/tmp/chef.#{bff_version}.bff", "/var/cache/omnibus/pkg/chef.#{bff_version}.bff"
    end

    def pkgmk_version
      "#{build_version}-#{iteration}"
    end

    def run_pkgmk
      install_dirname = File.dirname(install_path)
      install_basename = File.basename(install_path)

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

      shellout!("pkgmk -o -r #{install_dirname} -d /tmp/pkgmk -f /tmp/pkgmk/Prototype", timeout: 3600)

      system 'pkgchk -vd /tmp/pkgmk chef'

      system "pkgtrans /tmp/pkgmk /var/cache/omnibus/pkg/#{output_package("pkgmk")} chef"
    end

    def run_mac_package_build
      Packagers::MacPkg.new(self).build
    end

    # Runs the necessary command to make a package with fpm. As a side-effect,
    # sets `output_package`
    # @return void
    def run_fpm(pkg_type)
      run_package_command(fpm_command(pkg_type).join(' '))
    end

    # Executes the given command via mixlib-shellout.
    # @return [Mixlib::ShellOut] returns the underlying Mixlib::ShellOut
    #   object, so the caller can inspect the stdout and stderr.
    def run_package_command(cmd)
      cmd_options = {
        timeout: 3600,
        cwd: config.package_dir,
      }

      if cmd.is_a?(Array)
        command = cmd[0]
        cmd_options.merge!(cmd[1])
      else
        command = cmd
      end

      shellout!(command, cmd_options)
    end

    # Dynamically generate Rake tasks to build projects and all the software they depend on.
    #
    # @note Much Rake magic ahead!
    #
    # @return void
    def render_tasks
      directory config.package_dir
      directory 'pkg'

      namespace :projects do
        namespace @name do

          package_types.each do |pkg_type|
            dep_tasks = @dependencies.map { |dep| "software:#{dep}" }
            dep_tasks << config.package_dir
            dep_tasks << 'health_check'

            desc "package #{@name} into a #{pkg_type}"
            task pkg_type => dep_tasks do
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
              else # pkg_type == "fpm"
                run_fpm(pkg_type)
              end

              render_metadata(pkg_type)

            end
          end

          task 'copy' => package_types do
            if OHAI.platform == 'windows'
              cp_cmd = "xcopy #{config.package_dir}\\*.msi pkg\\ /Y"
            elsif OHAI.platform == 'aix'
              cp_cmd = "cp #{config.package_dir}/*.bff pkg/"
            else
              cp_cmd = "cp #{config.package_dir}/* pkg/"
            end
            shell = Mixlib::ShellOut.new(cp_cmd)
            shell.run_command
            shell.error!
          end
          task 'copy' => 'pkg'

          desc "run the health check on the #{@name} install path"
          task 'health_check' do
            if OHAI.platform == 'windows'
              puts 'Skipping health check on windows...'
            else
              # build a list of all whitelist files from all project dependencies
              whitelist_files = library.components.map { |component| component.whitelist_files }.flatten
              Omnibus::HealthCheck.run(install_path, whitelist_files)
            end
          end
        end

        desc "package #{@name}"
        task @name => "#{@name}:copy"
      end
    end
  end
end
