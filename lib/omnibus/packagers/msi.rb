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

module Omnibus
  class Packager::MSI < Packager::Base
    id :msi

    setup do
      # Render the localization
      write_localization_file

      # Render the msi parameters
      write_parameters_file

      # Render the source file
      write_source_file

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
    end

    build do
      # Harvest the files with heat.exe, recursively generate fragment for
      # project directory
      execute <<-EOH.split.join(' ').squeeze(' ').strip
        heat.exe dir "#{windows_safe_path(project.install_dir)}"
          -nologo -srd -gg -cg ProjectDir
          -dr PROJECTLOCATION
          -var "var.ProjectSourceDir"
          -out "project-files.wxs"
      EOH

      # Compile with candle.exe
      execute <<-EOH.split.join(' ').squeeze(' ').strip
        candle.exe
          -nologo
          -dProjectSourceDir="#{windows_safe_path(project.install_dir)}" "project-files.wxs"
          "#{windows_safe_path(staging_dir, 'source.wxs')}"
      EOH

      # Create the msi, ignoring the 204 return code from light.exe since it is
      # about some expected warnings
      execute <<-EOH.split.join(' ').squeeze(' ').strip
        light.exe
          -nologo
          -ext WixUIExtension
          -cultures:en-us
          -loc "#{windows_safe_path(staging_dir, 'localization-en-us.wxl')}"
          project-files.wixobj source.wixobj
          -out "#{windows_safe_path(package_dir, package_name)}"
      EOH
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
        @upgrade_code || raise(MissingRequiredAttribute.new(self, :upgrade_code, '2CD7259C-776D-4DDB-A4C8-6E544E580AA1'))
      else
        unless val.is_a?(String)
          raise InvalidValue.new(:parameters, 'be a String')
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
          raise InvalidValue.new(:parameters, 'be a Hash')
        end

        @parameters = val
      end
    end
    expose :parameters

    #
    # @!endgroup
    # --------------------------------------------------

    # @see Base#package_name
    def package_name
      "#{project.name}-#{project.build_version}-#{project.build_iteration}.msi"
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
      render_template(resource_path('localization-en-us.wxl.erb'),
        destination: "#{staging_dir}/localization-en-us.wxl",
        variables: {
          name:          project.name,
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
      render_template(resource_path('parameters.wxi.erb'),
        destination: "#{staging_dir}/parameters.wxi",
        variables: {
          name:            project.name,
          friendly_name:   project.friendly_name,
          maintainer:      project.maintainer,
          upgrade_code:    upgrade_code,
          parameters:      parameters,
          version:         msi_version,
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
      render_template(resource_path('source.wxs.erb'),
        destination: "#{staging_dir}/source.wxs",
        variables: {
          name:          project.name,
          friendly_name: project.friendly_name,
          maintainer:    project.maintainer,
        }
      )
    end

    #
    # Parse and return the MSI version from the {Project#build_version}.
    #
    # A project's +build_version+ looks something like:
    #
    #     dev builds => 11.14.0-alpha.1+20140501194641.git.94.561b564
    #                => 0.0.0+20140506165802.1
    #
    #     rel builds => 11.14.0.alpha.1 || 11.14.0
    #
    # The MSI version spec expects a version that looks like X.Y.Z.W where
    # X, Y, Z & W are all 32 bit integers.
    #
    # @return [String]
    #
    def msi_version
      versions = project.build_version.split(/[.+-]/)
      "#{versions[0]}.#{versions[1]}.#{versions[2]}.#{project.build_iteration}"
    end

    #
    # The display version calculated from the {Project#build_version}.
    #
    # @see #msi_version an explanation of the breakdown
    #
    # @return [String]
    #
    def msi_display_version
      versions = project.build_version.split(/[.+-]/)
      "#{versions[0]}.#{versions[1]}.#{versions[2]}"
    end
  end
end
