#
# Copyright:: Copyright (c) 2012 Opscode, Inc.
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
require 'omnibus/exceptions'

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

    # @todo Why not just use `nil`?
    NULL_ARG = Object.new

    attr_reader :dependencies

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
    #
    # @todo Remove filename parameter, as it is unused.
    def initialize(io, filename)
      @exclusions = Array.new
      @runtime_dependencies = Array.new
      instance_eval(io)
      render_tasks
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
    def name(val=NULL_ARG)
      @name = val unless val.equal?(NULL_ARG)
      @name || raise(MissingProjectConfiguration.new("name", "my_project"))
    end

    # Set or retrieve the package name of the project.  Unless
    # explicitly set, the package name defaults to the project name
    #
    # @param val [String] the package name to set
    # @return [String]
    def package_name(val=NULL_ARG)
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
    def install_path(val=NULL_ARG)
      @install_path = val unless val.equal?(NULL_ARG)
      @install_path || raise(MissingProjectConfiguration.new("install_path", "/opt/opscode"))
    end

    # Set or retrieve the the package maintainer.
    #
    # @param val [String]
    # @return [String]
    #
    # @raise [MissingProjectConfiguration] if a value was not set
    #   before being subsequently retrieved (i.e., a maintainer must
    #   be set in order to build a project)
    def maintainer(val=NULL_ARG)
      @maintainer = val unless val.equal?(NULL_ARG)
      @maintainer || raise(MissingProjectConfiguration.new("maintainer", "Opscode, Inc."))
    end

    # Set or retrive the package homepage.
    #
    # @param val [String]
    # @return [String]
    #
    # @raise [MissingProjectConfiguration] if a value was not set
    #   before being subsequently retrieved (i.e., a homepage must be
    #   set in order to build a project)
    def homepage(val=NULL_ARG)
      @homepage = val unless val.equal?(NULL_ARG)
      @homepage || raise(MissingProjectConfiguration.new("homepage", "http://www.opscode.com"))
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
        maj = $1
        "#{build_iteration}.el#{maj}"
      when 'windows'
        "#{build_iteration}.windows"
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
    def description(val=NULL_ARG)
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
    def replaces(val=NULL_ARG)
      @replaces = val unless val.equal?(NULL_ARG)
      @replaces
    end

    # Set or retrieve the version of the project.
    #
    # @param val [String] the version to set
    # @return [String]
    #
    # @see Omnibus::BuildVersion
    def build_version(val=NULL_ARG)
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
    def build_iteration(val=NULL_ARG)
      @build_iteration = val unless val.equal?(NULL_ARG)
      @build_iteration || 1
    end

    # Set or retrieve the list of software dependencies for this
    # project.  As this is a DSL method, only pass the names of
    # software components, not {Omnibus::Software} objects.
    #
    # These is the software that comprises your project, and is
    # distinct from runtime dependencies.
    #
    # @param val [Array<String>] a list of names of Software components
    # @return [Array<String>]
    #
    # @see Omnibus::Software
    # @see #runtime_dependencies
    #
    # @todo Consider renaming / aliasing this to "components" to
    #   prevent confusion with {#runtime_dependencies}
    # @todo Why does this class also have a `dependencies` attribute
    #   reader defined?  I suppose this overwrites it, eh?  It should
    #   be removed.
    # @todo It would be more useful to have a `depend` method (similar
    #   to {#exclude}), that appends to an array.  That would
    #   eliminate patterns like we see in omnibus-chef, where we have
    #   code like:
    #     deps = []
    #     deps << "chef"
    #     ...
    #     dependencies deps
    def dependencies(val=NULL_ARG)
      @dependencies = val unless val.equal?(NULL_ARG)
      @dependencies
    end

    # Set the names of packages that are runtime dependencies of this
    # project.
    #
    # Corresponds to the `--depends` flag of
    # {https://github.com/jordansissel/fpm fpm}.
    #
    # @param val [Array<String>]
    #
    # @return [Array<String>]
    #
    # @todo Is it useful to rename / alias this to "depends", in
    #   keeping with the usage in fpm, as well as our own # {#replaces}
    #   method?
    # @todo This method should to be brought into line with the other
    #   DSL methods, and not have @runtime_dependencies initialized in
    #   the constructor.
    def runtime_dependencies(val)
      @runtime_dependencies = val
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
        [ "deb" ]
      when 'fedora', 'rhel'
        [ "rpm" ]
      when 'solaris2'
        [ "solaris" ]
      when 'windows'
        [ "msi" ]
      else
        [ "makeself" ]
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
             elsif
               software
             end
      @dependencies.include?(name)
    end

    # @!endgroup

    private

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
      msi_command = ["light.exe",
                     "-nologo",
                     "-ext WixUIExtension",
                     "-cultures:en-us",
                     "-loc #{install_path}\\msi-tmp\\#{package_name}-en-us.wxl",
                     "#{install_path}\\msi-tmp\\#{package_name}-Files.wixobj",
                     "#{install_path}\\msi-tmp\\#{package_name}.wixobj",
                     "-out #{config.package_dir}\\#{package_name}-#{build_version}-#{iteration}.msi"]

      # Don't care about the 204 return code from light.exe since it's
      # about some expected warnings...
      [msi_command.join(" "), {:returns => [0, 204]}]
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
      command_and_opts = ["fpm",
                          "-s dir",
                          "-t #{pkg_type}",
                          "-v #{build_version}",
                          "-n #{package_name}",
                          "--iteration #{iteration}",
                          install_path,
                          "-m '#{maintainer}'",
                          "--description '#{description}'",
                          "--url #{homepage}"]
      if File.exist?("#{package_scripts_path}/postinst")
        command_and_opts << "--post-install '#{package_scripts_path}/postinst'"
      end
      # solaris packages don't support --pre-uninstall
      if File.exist?("#{package_scripts_path}/prerm") && pkg_type != "solaris"
        command_and_opts << "--pre-uninstall '#{package_scripts_path}/prerm'"
      end
      # solaris packages don't support --post-uninstall
      if File.exist?("#{package_scripts_path}/postrm") && pkg_type != "solaris"
        command_and_opts << "--post-uninstall '#{package_scripts_path}/postrm'"
      end

      @exclusions.each do |pattern|
        command_and_opts << "--exclude '#{pattern}'"
      end

      @runtime_dependencies.each do |runtime_dep|
        command_and_opts << "--depends '#{runtime_dep}'"
      end

      command_and_opts << " --replaces #{@replaces}" if @replaces
      command_and_opts
    end

    # TODO: what's this do?
    def makeself_command
      command_and_opts = [ File.expand_path(File.join(Omnibus.source_root, "bin", "makeself.sh")),
                           "--gzip",
                           install_path,
                           "#{package_name}-#{build_version}_#{iteration}.sh",
                           "'The full stack of #{@name}'"
                         ]
      command_and_opts << "./makeselfinst" if File.exists?("#{package_scripts_path}/makeselfinst")
      command_and_opts
    end

    # Dynamically generate Rake tasks to build projects and all the software they depend on.
    #
    # @note Much Rake magic ahead!
    #
    # @return void
    def render_tasks
      directory config.package_dir
      directory "pkg"

      namespace :projects do

        package_types.each do |pkg_type|
          namespace @name do
            desc "package #{@name} into a #{pkg_type}"
            task pkg_type => (@dependencies.map {|dep| "software:#{dep}"}) do

              package_commands = []
              if pkg_type == "makeself"
                # copy the makeself installer into package
                if File.exists?("#{package_scripts_path}/makeselfinst")
                  package_commands << "cp #{package_scripts_path}/makeselfinst #{install_path}/"
                end

                # run the makeself program
                package_commands << makeself_command.join(" ")

                # rm the makeself installer (for incremental builds)
                package_commands << "rm -f #{install_path}/makeselfinst"
              elsif pkg_type == "msi"
                package_commands <<  msi_command
              else # pkg_type == "fpm"
                package_commands <<  fpm_command(pkg_type).join(" ")
              end

              # run the commands
              package_commands.each do |cmd|
                cmd_options = {
                  :live_stream => STDOUT,
                  :timeout => 3600,
                  :cwd => config.package_dir
                }

                if cmd.is_a?(Array)
                  command = cmd[0]
                  cmd_options.merge!(cmd[1])
                else
                  command = cmd
                end

                shell = Mixlib::ShellOut.new(command, cmd_options)
                shell.run_command
                shell.error!
              end
            end

            # TODO: why aren't these dependencies just added in at the
            # initial creation of the 'pkg_type' task?
            task pkg_type => config.package_dir
            task pkg_type => "#{@name}:health_check"
          end
        end

        task "#{@name}:copy" => (package_types.map {|pkg_type| "#{@name}:#{pkg_type}"}) do
          if OHAI.platform == "windows"
            cp_cmd = "xcopy #{config.package_dir}\\*.msi pkg\\ /Y"
          else
            cp_cmd = "cp #{config.package_dir}/* pkg/"
          end
          shell = Mixlib::ShellOut.new(cp_cmd)
          shell.run_command
          shell.error!
        end
        task "#{@name}:copy" => "pkg"

        desc "package #{@name}"
        task @name => "#{@name}:copy"

        desc "run the health check on the #{@name} install path"
        task "#{@name}:health_check" do
          if OHAI.platform == "windows"
            puts "Skipping health check on windows..."
          else
            Omnibus::HealthCheck.run(install_path)
          end
        end
      end
    end
  end
end
