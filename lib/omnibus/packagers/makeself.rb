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
  # Builds a makeself package (.sh extention)
  #
  class Packager::Makeself < Packager::Base

    validate do
      assert_presence!(makeself_script)
    end

    setup do
      purge_directory(staging_dir)
      purge_directory(staging_resources_path)
      copy_directory(resources_path, staging_resources_path)

      if self_install?
        copy_file("#{project.package_scripts_path}/makeselfinst", "#{project.install_dir}/makeselfinst")
      end
    end

    build do
      execute(makeself_cmd)

      if self_install?
        execute('./makeselfinst')
      end
    end

    clean do
      execute("rm -f #{project.install_dir}/makeselfinst")
    end

    # @see Base#package_name
    def package_name
      "#{project.package_name}-#{project.build_version}_#{project.build_iteration}.#{Ohai['kernel']['machine']}.sh"
    end

    def makeself_script
      Omnibus.source_root.join('bin', 'makeself.sh')
    end

    def makeself_cmd
      command_and_opts = [
        makeself_script,
        '--gzip',
        project.install_dir,
        package_name,
        "'The full stack of #{project.name}'",
      ].join(' ')
    end

    def self_install?
      File.exist?("#{project.package_scripts_path}/makeselfinst")
    end
  end
end
