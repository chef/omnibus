#
# Copyright:: Copyright (c) 2014 Chef Software, Inc.
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

module Omnibus
  #
  # Builds a Windows MSI package (.msi extension)
  #
  class Packager::MSI < Packager::Base
    # !@method msi_parameters
    #   @return (see Project#msi_parameters)
    def_delegator :@project, :msi_parameters, :msi_parameters

    validate do
      assert_presence!(resource('localization-en-us.wxl'))
      assert_presence!(resource('parameters.wxi'))
      assert_presence!(resource('source.wxs'))
    end

    setup do

      # Set the MSI version before rendering MSI source files
      set_msi_version_from_project

      %w(localization-en-us.wxl.erb parameters.wxi.erb source.wxs.erb).each do |filename|
        resource_path = resource(filename)
        destination   = File.join(staging_dir, filename.chomp('.erb'))

        if File.exist?(resource_path)
          render_template(resource_path, destination: destination)
        end
      end
    end

    build do
      # harvest the files with heat.exe
      # recursively generate fragment for project directory
      execute [
        "heat.exe dir \"#{project.install_dir}\"",
        '-nologo -srd -gg -cg ProjectDir',
        '-dr PROJECTLOCATION -var var.ProjectSourceDir',
        '-out project-files.wxs',
      ].join(' ')

      # compile with candle.exe
      execute [
        'candle.exe -nologo',
        "-dProjectSourceDir=\"#{project.install_dir}\" project-files.wxs",
        "\"#{resource('source.wxs')}\"",
      ].join(' ')

      # create the msi
      # Don't care about the 204 return code from light.exe since it's
      # about some expected warnings...
      execute [
        'light.exe -nologo -ext WixUIExtension -cultures:en-us',
        "-loc #{resource('localization-en-us.wxl')}",
        'project-files.wixobj source.wixobj',
        "-out \"#{final_pkg}\"",
      ].join(' '), returns: [0, 204]
    end

    clean do
    end

    # @see Base#package_name
    def package_name
      "#{project.name}-#{project.build_version}-#{project.iteration}.msi"
    end

    # The full path where the product package was/will be written.
    #
    # @return [String] Path to the packge file.
    def final_pkg
      File.expand_path("#{package_dir}/#{package_name}")
    end

    # Helper method to set the msi version for a given project
    def set_msi_version_from_project
      # build_version looks something like this:
      # dev builds => 11.14.0-alpha.1+20140501194641.git.94.561b564
      #            => 0.0.0+20140506165802.1
      # rel builds => 11.14.0.alpha.1 || 11.14.0
      #
      # MSI version spec expects a version that looks like X.Y.Z.W where
      # X, Y, Z & W are 32 bit integers.
      #
      # MSI source files expect two versions to be set in the msi_parameters:
      # msi_version & msi_display_version

      versions = project.build_version.split(/[.+-]/)
      @msi_version = "#{versions[0]}.#{versions[1]}.#{versions[2]}.#{project.build_iteration}"
      @msi_display_version = "#{versions[0]}.#{versions[1]}.#{versions[2]}"
    end
  end
end
