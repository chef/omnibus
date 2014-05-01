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
  class Packager::WindowsMsi < Packager::Base
    # !@method msi_parameters
    #   @return (see Project#msi_parameters)
    def_delegator :@project, :msi_parameters, :msi_parameters

    validate do
      assert_presence!(resource('localization-en-us.wxl'))
      assert_presence!(resource('parameters.wxi'))
      assert_presence!(resource('source.wxs'))
    end

    setup do
      purge_directory(staging_dir)
      purge_directory(project.package_dir)
      purge_directory(staging_resources_path)
      copy_directory(resources_path, staging_resources_path)

      [ 'localization-en-us.wxl.erb', 'parameters.wxi.erb', 'source.wxs.erb' ].each do |res|
        res_path = resource(res)
        render_template(res_path) if File.exist?(res_path)
      end
    end

    build do
      # harvest the files with heat.exe
      # recursively generate fragment for project directory
      execute [
        "heat.exe dir \"#{install_path}\"",
        "-nologo -srd -gg -cg ProjectDir",
        "-dr PROJECTLOCATION -var var.ProjectSourceDir",
        "-out project-files.wxs"
      ].join(" ")

      # compile with candle.exe
      execute [
        "candle.exe -nologo",
        "-dProjectSourceDir=\"#{install_path}\" project-files.wxs",
        "\"#{resource('source.wxs')}\""
      ].join(" ")

      # create the msi
      # Don't care about the 204 return code from light.exe since it's
      # about some expected warnings...
      execute [
        "light.exe -nologo -ext WixUIExtension -cultures:en-us",
        "-loc #{resource('localization-en-us.wxl')}",
        "project-files.wixobj source.wixobj",
        "-out \"#{final_pkg}\""
      ].join(" "), returns: [0, 204]
    end

    clean do
    end

    # @see Base#package_name
    def package_name
      "#{name}-#{version}-#{iteration}.msi"
    end

    # The full path where the product package was/will be written.
    #
    # @return [String] Path to the packge file.
    def final_pkg
      File.expand_path("#{project.package_dir}/#{package_name}")
    end
  end
end
