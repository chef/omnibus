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

#
# omnibus project dsl reader
#

module Omnibus
  class Project
    include Rake::DSL

    NULL_ARG = Object.new

    attr_reader :dependencies

    def self.load(filename)
      new(IO.read(filename), filename)
    end

    def self.all_projects
      @@projects ||= []
    end

    def initialize(io, filename)
      @exclusions = Array.new
      @runtime_dependencies = Array.new
      instance_eval(io)
      render_tasks
    end

    def name(val=NULL_ARG)
      @name = val unless val.equal?(NULL_ARG)
      @name
    end

    def package_name(val=NULL_ARG)
      @package_name = val unless val.equal?(NULL_ARG)
      @package_name.nil? ? @name : @package_name
    end

    def install_path(val=NULL_ARG)
      @install_path = val unless val.equal?(NULL_ARG)
      @install_path
    end

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

		def pkg_maintainer
			@maintainer.nil? ? "Opscode, Inc." : @maintainer
		end

		def maintainer(val=NULL_ARG)
			@maintainer = val unless val.equal?(NULL_ARG)
		end

    def description(val=NULL_ARG)
      @description = val unless val.equal?(NULL_ARG)
      @description
    end

		def pkg_description
			@description.nil? ? "The full stack of #{@name}" : @description
		end

		def url(val=NULL_ARG)
			@url = val unless val.equal?(NULL_ARG)
			@url
		end

		def pkg_url
			@url.nil? ? "http://www.opscode.com" : @url
		end

    def replaces(val=NULL_ARG)
      @replaces = val unless val.equal?(NULL_ARG)
      @replaces
    end

    def build_version(val=NULL_ARG)
      @build_version = val unless val.equal?(NULL_ARG)
      @build_version
    end

    def build_iteration(val=NULL_ARG)
      @build_iteration = val unless val.equal?(NULL_ARG)
      @build_iteration
    end

    def dependencies(val=NULL_ARG)
      @dependencies = val unless val.equal?(NULL_ARG)
      @dependencies
    end

    def runtime_dependencies(val)
      @runtime_dependencies = val
    end

		def conflicts(val)
			@conflicts = val
		end

    def exclude(pattern)
      @exclusions << pattern
    end

    def platform_version
      OHAI.platform_version
    end

    def platform
      OHAI.platform
    end

    def platform_family
      OHAI.platform_family
    end

    def config
      Omnibus.config
    end

    def package_scripts_path
      "#{Omnibus.root}/package-scripts/#{name}"
    end

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

    def dependency?(software)
      name = if software.respond_to?(:name)
               software.send(:name)
             elsif
               software
             end
      @dependencies.include?(name)
    end

    private

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
    
    def fpm_command(pkg_type)
      command_and_opts = ["fpm",
                          "-s dir",
                          "-t #{pkg_type}",
                          "-v #{build_version}",
                          "-n #{package_name}",
                          "--iteration #{iteration}",
                          install_path,
                          "-m '#{pkg_maintainer}'",
                          "--description '#{pkg_description}'",
                          "--url '#{pkg_url}'"]
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

			@conflicts.each do |conflict|
				command_and_opts << "--conflicts '#{conflict}'"
			end

      command_and_opts << " --replaces #{@replaces}" if @replaces
      command_and_opts
    end

    def makeself_command
      command_and_opts = [ File.expand_path(File.join(Omnibus.gem_root, "bin", "makeself.sh")),
                           "--gzip",
                           install_path,
                           "#{package_name}-#{build_version}_#{iteration}.sh",
                           "'The full stack of #{@name}'"
                         ]
      command_and_opts << "./makeselfinst" if File.exists?("#{package_scripts_path}/makeselfinst")
      command_and_opts
    end

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
