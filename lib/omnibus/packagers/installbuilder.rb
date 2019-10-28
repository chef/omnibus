#
# Copyright 2014-2019 Chef Software, Inc.
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

module Omnibus
  class Packager::InstallBuilder < Packager::Base
    id :installbuilder

    setup do
      # Copy the Installer content into our scratch directory, accounting for
      # any excluded files.
      #
      # /opt/hamlet => /tmp/daj29013/
      FileSyncer.sync(project.install_dir, staging_dir, exclude: exclusions)

      # Copy all the staging assets from vendored Omnibus into the resources directory.
      copy_files("#{Omnibus.source_root}/resources/#{id}/assets", "#{resources_dir}/assets")

      # Copy assets and InstallBuilder XML definition files
      # copy_files("#{resources_path}", staging_dir)
      shellout!("cp -r #{resources_path}/* #{staging_dir}/") # somehow copy_files does not work and cuts files in half...
    end

    build do
      platforms.each do |platform|
        log.debug(log_key) { "InstallBuilder building for platform #{platform} flavors key #{flavor_key} values #{flavor_values}" }
        if flavor_key && !flavor_values.empty?
          flavor_values.each do |flavor_value|
            log.debug(log_key) { "InstallBuilder building flavor key #{flavor_key} value #{flavor_value}" }
            installbuilder_build(platform, flavor_value)
          end
        else
          log.debug(log_key) { "InstallBuilder building non flavor" }
          installbuilder_build(platform)
        end
        copy_files(staging_dir, Config.package_dir, "*.#{extension(platform)}")
      end
    end

    #
    # Execute Installbuilder build for given platform
    #
    # @example
    #   installbuilder_build 'linux-x64'
    #
    # @param String platform
    #   Platform
    #
    # @return []
    #
    def installbuilder_build(platform, flavor = NULL)
      cmd = installbuilder_command(platform, flavor)

      log.info(log_key) { "Building #{package_name(platform, flavor)} with #{cmd}" }

      Dir.chdir(staging_dir) do
        # rubocop:disable Style/HashSyntax
        shellout!(cmd, :live_stream => STDOUT, :returns => [0])
        # rubocop:enable Style/HashSyntax
      end
    end

    #
    # Get the shell command to run InstallBuilder in order to build installer
    #
    # @example
    #   installbuilder_command 'linux-x64'
    #
    # @param String platform
    #   Platform
    #
    # @return [String]
    #   Full InstallBuilder command to run build
    #
    def installbuilder_command(platform, flavor = NULL)
      params = [
        "project.outputDirectory=#{staging_dir}",
        "project.version=#{build_version}",
        "project.installerFileName=#{package_name(platform, flavor)}",
      ]

      if flavor != NULL
        params.push "#{flavor_key}=#{flavor}"
      end

      parameters.each do |name, value|
        params.push "#{name}='#{value}'"
      end

      <<-EOH.split.join(" ").squeeze(" ").strip
        #{ib_executable} build #{staging_dir}/#{ib_project_file} #{platform}
        --license #{ib_license} --setvars #{params.join(" ")}
      EOH
    end

    #
    # Copy files from source dir to target
    #
    # @return []
    #
    def copy_files(source_dir, target_dir, pattern = "*")
      create_directory(target_dir)
      FileSyncer.glob("#{source_dir}/#{pattern}").each do |file|
        base_name = File.basename(file)
        target_path = "#{target_dir}/#{base_name}"

        if File.directory?(file)
          create_directory(target_path)
          copy_files("#{source_dir}/#{base_name}", "#{target_dir}/#{base_name}")
        else
          copy_file(file, target_path)
        end
      end
    end

    #
    # Set or retrieve the custom InstallBuilder building parameters.
    #
    # @example
    #   parameters {
    #     'MagicParam' => 'ABCD-1234'
    #   }
    #
    # @param [Hash] val
    #   the parameters to set
    #
    # @return [Hash]
    #   the set parameters
    #
    def parameters(val = NULL)
      if null?(val)
        @parameters || {}
      else
        unless val.is_a?(Hash)
          raise InvalidValue.new(:parameters, "be a Hash")
        end

        @parameters = val
      end
    end
    expose :parameters

    def flavors(flavor_key = NULL, flavor_values = NULL)
      if null?(flavor_key)
        @flavor_key
      else
        unless flavor_key.is_a?(String)
          raise InvalidValue.new(:flavor_key, "be a String")
        end
        unless flavor_values.is_a?(Array)
          raise InvalidValue.new(:flavor_values, "be a Array")
        end

        @flavor_key = flavor_key
        @flavor_values = flavor_values
      end
    end
    expose :flavors

    def flavor_key
      @flavor_key || NULL
    end

    def flavor_values
      @flavor_values || []
    end

    #
    # This is actually just the regular build_iteration, but it felt lonely
    # among all the other +safe_*+ methods.
    #
    # @return [String]
    #
    def safe_build_iteration
      project.build_iteration
    end

    #
    # @!endgroup
    # --------------------------------------------------

    def build_version
      project.build_version
    end

    # @see Base#package_name
    def package_name(platform = NULL, flavor = NULL)
      current_platform = platform || platforms[0]
      if null?(flavor)
        flavor_suffix = null?(flavor_key) ? "" : "-#{flavor_values[0]}"
      else
        flavor_suffix = "-#{flavor}"
      end
      "#{project_name}#{flavor_suffix}-#{build_version}-#{safe_architecture(current_platform)}.#{extension(current_platform)}"
    end

    #
    # Choose main part of package_name
    #
    # @example
    #   project_name 'my-app'
    #
    # @param String project_name
    #   Name of application/project, defaults to project.package_name
    #
    # @return [String]
    #   Set Project Name val
    #
    def project_name(val = NULL)
      if null?(val)
        @project_name || project.package_name
      else
        unless val.is_a?(String)
          raise InvalidValue.new(:project_name, "be an String")
        end
        @project_name = val
      end
    end
    expose :project_name

    #
    # Choose for which platforms build package
    #
    # @example
    #   platforms ['linux-x64']
    #
    # @param Array platforms
    #   Target Platforms for installer
    #
    # @return [String]
    #   Target platforms list
    #
    def platforms(val = NULL)
      if null?(val)
        @platforms || []
      else
        unless val.is_a?(Array)
          raise InvalidValue.new(:platforms, "be an Array")
        end
        @platforms = val
      end
    end
    expose :platforms

    #
    # Provide path to InstallBuilder executable binary
    #
    # @example
    #   ib_executable '/opt/ib/bin/builder'
    #
    # @param String val
    #   Path to IB executable, defaults to environment variable 'IB_EXECUTABLE'
    #
    # @return [String]
    #   Path to IB executable
    #
    def ib_executable(val = NULL)
      if null?(val)
        @ib_executable || "$IB_EXECUTABLE"
      else
        unless val.is_a?(String)
          raise InvalidValue.new(:ib_executable, "be an String")
        end
        unless File.file?(val)
          raise InvalidValue.new(:ib_executable, "must exist")
        end
        @ib_executable = val
      end
    end
    expose :ib_executable

    #
    # Provide path to InstallBuilder license file
    #
    # @example
    #   ib_license '/opt/ib/license.xml
    #
    # @param String val
    #   Path to IB license, defaults to environment variable 'IB_LICENSE'
    #
    # @return [String]
    #   Path to IB executable
    #
    def ib_license(val = NULL)
      if null?(val)
        @ib_license || ENV["IB_LICENSE"]
      else
        unless val.is_a?(String)
          raise InvalidValue.new(:ib_license, "be an String")
        end
        unless File.file?(val)
          raise InvalidValue.new(:ib_license, "must exist")
        end
        @ib_license = val
      end
    end
    expose :ib_license

    #
    # Provide file name of InstallBuilder project file to build
    #
    # @example
    #   ib_project_file 'file1.xml'
    #
    # @param String val
    #   IB project file name, defaults to 'project.xml'
    #
    # @return [String]
    #   IB project file name to build
    #
    def ib_project_file(val = NULL)
      if null?(val)
        @ib_project_file || "project.xml"
      else
        unless val.is_a?(String)
          raise InvalidValue.new(:ib_project_file, "be an String")
        end
        @ib_project_file = val
      end
    end
    expose :ib_project_file

    #
    # The path where the InstallBuilder resources will live.
    #
    # @return [String]
    #
    def resources_dir
      File.expand_path("#{staging_dir}/resources")
    end

    # The architecture for this package and given platform.
    #
    # @example
    #   safe_architecture
    #
    # @example
    #   safe_architecture 'windows'
    #
    # @param String platform
    #   Platform
    #
    # @return [String]
    #   Configured architecture in omnibus.rb or one provided by Ohai
    #
    def safe_architecture(platform = nil)
      (platform || platforms["0"]).eql?("windows") ? Config.windows_arch : Ohai["kernel"]["machine"]
    end

    #
    # The package extension for this package and given platform.
    #
    # @example
    #   extension
    #
    # @example
    #   extension 'windows'
    #
    # @param String platform
    #   Platform
    #
    # @return [String]
    #   File extension for given platform or for first in platforms array
    #
    def extension(platform = nil)
      (platform || platforms["0"]).eql?("windows") ? "exe" : "run"
    end
  end
end
