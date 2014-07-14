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
  # Builds a bff package (.bff extention)
  #
  class Packager::Bff < Packager::Base

    validate do
      assert_presence!("#{project.package_scripts_path}/aix/opscode.chef.client.template")
    end

    setup do
      purge_directory(staging_dir)
      purge_directory(Config.package_dir)
      purge_directory(staging_resources_path)
      copy_directory(resources_path, staging_resources_path)

      purge_directory('/.info')
      purge_directory('/tmp/bff')

      execute("find #{project.install_dir} -print > /tmp/bff/file.list")
      execute("cat #{project.package_scripts_path}/aix/opscode.chef.client.template | sed -e 's/TBS/#{bff_version}/' > /tmp/bff/gen.preamble")
      # @todo can we just use an erb template here?
      execute("cat /tmp/bff/gen.preamble /tmp/bff/file.list #{project.package_scripts_path}/aix/opscode.chef.client.template.last > /tmp/bff/gen.template")

      copy_file("#{project.package_scripts_path}/aix/unpostinstall.sh", "#{project.install_dir}/bin")
      copy_file("#{project.package_scripts_path}/aix/postinstall.sh", "#{project.install_dir}/bin")
    end

    build do
      execute(bff_command, { returns: [0] })
      copy_file("/tmp/chef.#{bff_version}.bff", "/var/cache/omnibus/pkg/chef.#{bff_version}.bff")
    end

    clean do
      # none
    end

    # @see Base#package_name
    def package_name
      "#{project.package_name}.#{bff_version}.#{Ohai['kernel']['machine']}.bff"
    end

    def bff_version
      project.build_version.split(/[^\d]/)[0..2].join('.') + ".#{project.build_iteration}"
    end

    def bff_command
      'sudo /usr/sbin/mkinstallp -d / -T /tmp/bff/gen.template'
    end
  end
end
