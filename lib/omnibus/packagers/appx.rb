#
# Copyright 2016 Chef Software, Inc.
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

require "omnibus/packagers/windows_base"

module Omnibus
  class Packager::APPX < Packager::WindowsBase
    id :appx

    setup do
      # Render the manifest
      write_manifest_file

      # Copy all the staging assets from vendored Omnibus into the resources
      # directory.
      FileSyncer.glob("#{Omnibus.source_root}/resources/#{id}/assets/*").each do |file|
        copy_file(file, "#{project.install_dir}/#{File.basename(file)}")
      end

      # Copy all assets in the user's project directory - this may overwrite
      # files copied in the previous step, but that's okay :)
      FileSyncer.glob("#{resources_path}/assets/*").each do |file|
        copy_file(file, "#{project.install_dir}/#{File.basename(file)}")
      end
    end

    build do
      # Pack the files with makeappx.exe, recursively generate fragment for
      # project directory
      Dir.chdir(staging_dir) do
        appx_file = windows_safe_path(Config.package_dir, package_name)
        shellout!(pack_command(appx_file))

        if signing_identity
          sign_package(appx_file)
        end
      end
    end

    # @see Base#package_name
    def package_name
      "#{project.package_name}-#{project.build_version}-#{project.build_iteration}.appx"
    end

    #
    # Write the manifest file into the staging directory.
    #
    # @return [void]
    #
    def write_manifest_file
      render_template(resource_path("AppxManifest.xml.erb"),
        destination: "#{windows_safe_path(project.install_dir)}/AppxManifest.xml",
        variables: {
          name:            project.package_name,
          friendly_name:   project.friendly_name,
          version:         windows_package_version,
          maintainer:      project.maintainer,
          certificate_subject: certificate_subject,
        }
      )
    end

    #
    # Get the shell command to run pack in order to create a
    # an appx package
    #
    # @return [String]
    #
    def pack_command(appx_file)
      "makeappx.exe pack /d \"#{windows_safe_path(project.install_dir)}\" /p #{appx_file}"
    end
  end
end
