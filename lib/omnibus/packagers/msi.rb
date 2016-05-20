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

require "pathname"
require "omnibus/packagers/windows_base"

module Omnibus
  class Packager::MSI < Packager::WindowsBase
    id :msi

    setup do
      # Render the localization
      write_localization_file

      # Render the msi parameters
      write_parameters_file

      # Render the source file
      write_source_file

      # Optionally, render the bundle file
      write_bundle_file if bundle_msi

      # Copy all the staging assets from vendored Omnibus into the resources
      # directory.
      create_directory("#{resources_dir}/assets")
      FileSyncer.glob("#{Omnibus.source_root}/resources/#{id}/assets/*").each do |file|
        copy_file(file, "#{resources_dir}/assets/#{File.basename(file)}")
      end

      # Copy all assets in the user's project directory - this may overwrite
      # files copied in the previous step, but that's okay :)
      FileSyncer.glob("#{resources_path}/assets/*").each do |file|
        copy_file(file, "#{resources_dir}/assets/#{File.basename(file)}")
      end

      # Source for the custom action is at https://github.com/chef/fastmsi-custom-action
      # The dll will be built separately as part of the custom action build process
      # and made available as a binary for the Omnibus projects to use.
      copy_file(resource_path("CustomActionFastMsi.CA.dll"), staging_dir) if fast_msi
    end

    build do
      # If fastmsi, zip up the contents of the install directory
      shellout!(zip_command) if fast_msi

      # Harvest the files with heat.exe, recursively generate fragment for
      # project directory
      Dir.chdir(staging_dir) do
        shellout!(heat_command)

        # Compile with candle.exe
        shellout!(candle_command)

        # Create the msi, ignoring the 204 return code from light.exe since it is
        # about some expected warnings
        msi_file = windows_safe_path(Config.package_dir, msi_name)
        shellout!(light_command(msi_file), returns: [0, 204])

        if signing_identity
          sign_package(msi_file)
        end

        # This assumes, rightly or wrongly, that any installers we want to bundle
        # into our installer will be downloaded by omnibus and put in the cache dir
        if bundle_msi
          shellout!(candle_command(is_bundle: true))

          bundle_file = windows_safe_path(Config.package_dir, bundle_name)
          shellout!(light_command(bundle_file, is_bundle: true), returns: [0, 204])

          if signing_identity
            sign_package(bundle_file)
          end
        end
      end
    end

    #
    # @!group DSL methods
    # --------------------------------------------------

    #
    # Set or retrieve the upgrade code.
    #
    # @example
    #   upgrade_code 'ABCD-1234'
    #
    # @param [Hash] val
    #   the UpgradeCode to set
    #
    # @return [Hash]
    #   the set UpgradeCode
    #
    def upgrade_code(val = NULL)
      if null?(val)
        @upgrade_code || raise(MissingRequiredAttribute.new(self, :upgrade_code, "2CD7259C-776D-4DDB-A4C8-6E544E580AA1"))
      else
        unless val.is_a?(String)
          raise InvalidValue.new(:upgrade_code, "be a String")
        end

        @upgrade_code = val
      end
    end
    expose :upgrade_code

    #
    # Set or retrieve the custom msi building parameters.
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

    #
    # Set the wix light extensions to load
    #
    # @example
    #   wix_light_extension 'WixUtilExtension'
    #
    # @param [String] extension
    #   A list of extensions to load
    #
    # @return [Array]
    #   The list of extensions that will be loaded
    #
    def wix_light_extension(extension)
      unless extension.is_a?(String)
        raise InvalidValue.new(:wix_light_extension, "be an String")
      end

      wix_light_extensions << extension
    end
    expose :wix_light_extension

    #
    # Set the wix candle extensions to load
    #
    # @example
    #   wix_candle_extension 'WixUtilExtension'
    #
    # @param [String] extension
    #   A list of extensions to load
    #
    # @return [Array]
    #   The list of extensions that will be loaded
    #
    def wix_candle_extension(extension)
      unless extension.is_a?(String)
        raise InvalidValue.new(:wix_candle_extension, "be an String")
      end

      wix_candle_extensions << extension
    end
    expose :wix_candle_extension

    #
    # Signal that we're building a bundle rather than a single package
    #
    # @example
    #   bundle_msi true
    #
    # @param [TrueClass, FalseClass] value
    #   whether we're a bundle or not
    #
    # @return [TrueClass, FalseClass]
    #   whether we're a bundle or not
    def bundle_msi(val = false)
      unless val.is_a?(TrueClass) || val.is_a?(FalseClass)
        raise InvalidValue.new(:bundle_msi, "be TrueClass or FalseClass")
      end
      @bundle_msi ||= val
    end
    expose :bundle_msi

    #
    # Signal that we're building a zip-based MSI
    #
    # @example
    #   fast_msi true
    #
    # @param [TrueClass, FalseClass] value
    #   whether we're building a zip-based MSI or not
    #
    # @return [TrueClass, FalseClass]
    #   whether we're building a zip-based MSI or not
    def fast_msi(val = false)
      unless val.is_a?(TrueClass) || val.is_a?(FalseClass)
        raise InvalidValue.new(:fast_msi, "be TrueClass or FalseClass")
      end
      @fast_msi ||= val
    end
    expose :fast_msi

    #
    # Discovers a path to a gem/file included in a gem under the install directory.
    #
    # @example
    #   gem_path 'chef-[0-9]*-mingw32' -> 'some/path/to/gems/chef-version-mingw32'
    #
    # @param [String] glob
    #   a ruby acceptable glob path such as with **, *, [] etc.
    #
    # @return [String] path relative to the project's install_dir
    #
    # Raises exception the glob matches 0 or more than 1 file/directory.
    #
    def gem_path(glob = NULL)
      unless glob.is_a?(String) || null?(glob)
        raise InvalidValue.new(:glob, "be an String")
      end

      install_path = Pathname.new(project.install_dir)

      # Find path in which the Chef gem is installed
      search_pattern = install_path.join("**", "gems")
      search_pattern = search_pattern.join(glob) unless null?(glob)
      file_paths = Pathname.glob(search_pattern).find

      raise "Could not find `#{search_pattern}'!" if file_paths.none?
      raise "Multiple possible matches of `#{search_pattern}'! : #{file_paths}" if file_paths.count > 1
      file_paths.first.relative_path_from(install_path).to_s
    end
    expose :gem_path

    #
    # @!endgroup
    # --------------------------------------------------

    # @see Base#package_name
    def package_name
      bundle_msi ? bundle_name : msi_name
    end

    def msi_name
      "#{project.package_name}-#{project.build_version}-#{project.build_iteration}-#{Config.windows_arch}.msi"
    end

    def bundle_name
      "#{project.package_name}-#{project.build_version}-#{project.build_iteration}-#{Config.windows_arch}.exe"
    end

    #
    # The path where the MSI resources will live.
    #
    # @return [String]
    #
    def resources_dir
      File.expand_path("#{staging_dir}/Resources")
    end

    #
    # Write the localization file into the staging directory.
    #
    # @return [void]
    #
    def write_localization_file
      render_template(resource_path("localization-en-us.wxl.erb"),
        destination: "#{staging_dir}/localization-en-us.wxl",
        variables: {
          name:          project.package_name,
          friendly_name: project.friendly_name,
          maintainer:    project.maintainer,
        }
      )
    end

    #
    # Write the parameters file into the staging directory.
    #
    # @return [void]
    #
    def write_parameters_file
      render_template(resource_path("parameters.wxi.erb"),
        destination: "#{staging_dir}/parameters.wxi",
        variables: {
          name:            project.package_name,
          friendly_name:   project.friendly_name,
          maintainer:      project.maintainer,
          upgrade_code:    upgrade_code,
          parameters:      parameters,
          version:         windows_package_version,
          display_version: msi_display_version,
        }
      )
    end

    #
    # Write the source file into the staging directory.
    #
    # @return [void]
    #
    def write_source_file
      paths = []

      # Remove C:/
      install_dir = project.install_dir.split("/")[1..-1].join("/")

      # Grab all parent paths
      Pathname.new(install_dir).ascend do |path|
        paths << path.to_s
      end

      # Create the hierarchy
      hierarchy = paths.reverse.inject({}) do |hash, path|
        hash[File.basename(path)] = path.gsub(/[^[:alnum:]]/, "").upcase + "LOCATION"
        hash
      end

      # The last item in the path MUST be named PROJECTLOCATION or else space
      # robots will cause permanent damage to you and your family.
      hierarchy[hierarchy.keys.last] = "PROJECTLOCATION"

      # If the path hierarchy is > 1, the customizable installation directory
      # should default to the second-to-last item in the hierarchy. If the
      # hierarchy is smaller than that, then just use the system drive.
      wix_install_dir = if hierarchy.size > 1
                          hierarchy.to_a[-2][1]
                        else
                          "WINDOWSVOLUME"
                        end

      render_template(resource_path("source.wxs.erb"),
        destination: "#{staging_dir}/source.wxs",
        variables: {
          name:          project.package_name,
          friendly_name: project.friendly_name,
          maintainer:    project.maintainer,
          hierarchy:     hierarchy,
          fastmsi:       fast_msi,
          wix_install_dir: wix_install_dir,
        }
      )
    end

    #
    # Write the bundle file into the staging directory.
    #
    # @return [void]
    #
    def write_bundle_file
      render_template(resource_path("bundle.wxs.erb"),
        destination: "#{staging_dir}/bundle.wxs",
        variables: {
          name:            project.package_name,
          friendly_name:   project.friendly_name,
          maintainer:      project.maintainer,
          upgrade_code:    upgrade_code,
          parameters:      parameters,
          version:         windows_package_version,
          display_version: msi_display_version,
          msi:             windows_safe_path(Config.package_dir, msi_name),
        }
      )
    end

    #
    # Get the shell command to create a zip file that contains
    # the contents of the project install directory
    #
    # @return [String]
    #
    def zip_command
      <<-EOH.split.join(" ").squeeze(" ").strip
      7z a -r
      #{windows_safe_path(staging_dir)}\\#{project.name}.zip
      #{windows_safe_path(project.install_dir)}\\*
      EOH
    end

    #
    # Get the shell command to run heat in order to create a
    # a WIX manifest of project files to be packaged into the MSI
    #
    # @return [String]
    #
    def heat_command
      if fast_msi
        <<-EOH.split.join(" ").squeeze(" ").strip
          heat.exe file "#{project.name}.zip"
          -cg ProjectDir
          -dr INSTALLLOCATION
          -nologo -sfrag -srd -sreg -gg
          -out "project-files.wxs"
        EOH
      else
        <<-EOH.split.join(" ").squeeze(" ").strip
          heat.exe dir "#{windows_safe_path(project.install_dir)}"
            -nologo -srd -sreg -gg -cg ProjectDir
            -dr PROJECTLOCATION
            -var "var.ProjectSourceDir"
            -out "project-files.wxs"
        EOH
      end
    end

    #
    # Get the shell command to complie the project WIX files
    #
    # @return [String]
    #
    def candle_command(is_bundle: false)
      if is_bundle
        <<-EOH.split.join(" ").squeeze(" ").strip
        candle.exe
          -nologo
          #{wix_candle_flags}
          -ext WixBalExtension
          #{wix_extension_switches(wix_candle_extensions)}
          -dOmnibusCacheDir="#{windows_safe_path(File.expand_path(Config.cache_dir))}"
          "#{windows_safe_path(staging_dir, 'bundle.wxs')}"
        EOH
      else
        <<-EOH.split.join(" ").squeeze(" ").strip
          candle.exe
            -nologo
            #{wix_candle_flags}
            #{wix_extension_switches(wix_candle_extensions)}
            -dProjectSourceDir="#{windows_safe_path(project.install_dir)}" "project-files.wxs"
            "#{windows_safe_path(staging_dir, 'source.wxs')}"
        EOH
      end
    end

    #
    # Get the shell command to link the project WIX object files
    #
    # @return [String]
    #
    def light_command(out_file, is_bundle: false)
      if is_bundle
        <<-EOH.split.join(" ").squeeze(" ").strip
        light.exe
          -nologo
          -ext WixUIExtension
          -ext WixBalExtension
          #{wix_extension_switches(wix_light_extensions)}
          -cultures:en-us
          -loc "#{windows_safe_path(staging_dir, 'localization-en-us.wxl')}"
          bundle.wixobj
          -out "#{out_file}"
        EOH
      else
        <<-EOH.split.join(" ").squeeze(" ").strip
          light.exe
            -nologo
            -ext WixUIExtension
            #{wix_extension_switches(wix_light_extensions)}
            -cultures:en-us
            -loc "#{windows_safe_path(staging_dir, 'localization-en-us.wxl')}"
            project-files.wixobj source.wixobj
            -out "#{out_file}"
        EOH
      end
    end

    #
    # The display version calculated from the {Project#build_version}.
    #
    # @see #windows_package_version an explanation of the breakdown
    #
    # @return [String]
    #
    def msi_display_version
      versions = project.build_version.split(/[.+-]/)
      "#{versions[0]}.#{versions[1]}.#{versions[2]}"
    end

    #
    # Returns the extensions to use for light
    #
    # @return [Array]
    #   the extensions that will be loaded for light
    #
    def wix_light_extensions
      @wix_light_extensions ||= []
    end

    #
    # Returns the extensions to use for candle
    #
    # @return [Array]
    #   the extensions that will be loaded for candle
    #
    def wix_candle_extensions
      @wix_candle_extensions ||= []
    end

    #
    # Returns the options to use for candle
    #
    # @return [Array]
    #   the extensions that will be loaded for candle
    #
    def wix_candle_flags
      # we support x86 or x64.  No Itanium support (ia64).
      @wix_candle_flags ||= "-arch " + (Config.windows_arch.to_sym == :x86 ? "x86" : "x64")
    end

    #
    # Takes an array of wix extension names and creates a string
    # that can be passed to wix to load those.
    #
    # for example,
    # ['a', 'b'] => "-ext 'a' -ext 'b'"
    #
    # @return [String]
    #
    def wix_extension_switches(arr)
      "#{arr.map { |e| "-ext '#{e}'" }.join(' ')}"
    end
  end
end
