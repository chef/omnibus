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
  #
  # Builds a bff package (.bff extention)
  #
  class Packager::BFF < Packager::Base
    id :bff

    validate do
      assert_presence!("#{project.package_scripts_path}/aix/opscode.chef.client.template")
    end

    setup do
      purge_directory('/.info')
      purge_directory('/tmp/bff')

      create_gen_template

      copy_file("#{project.package_scripts_path}/aix/unpostinstall.sh", "#{project.install_dir}/bin")
      copy_file("#{project.package_scripts_path}/aix/postinstall.sh", "#{project.install_dir}/bin")
    end

    build do
      execute(bff_command, { returns: [0] })
      copy_file("/tmp/chef.#{bff_version}.bff", "/var/cache/omnibus/pkg/chef.#{bff_version}.bff")
    end

    # @see Base#package_name
    def package_name
      "#{project.name}.#{bff_version}.#{Ohai['kernel']['machine']}.bff"
    end

    def bff_version
      project.build_version.split(/[^\d]/)[0..2].join('.') + ".#{project.build_iteration}"
    end

    def bff_command
      'sudo /usr/sbin/mkinstallp -d / -T /tmp/bff/gen.template'
    end

    def create_gen_template
      preamble = <<-EOF.gsub(/^ {8}/, '')
        Package Name: #{project.name}
        Package VRMF: #{bff_version}
        Update: N
        Fileset
          Fileset Name: #{project.name}
          Fileset VRMF: #{bff_version}
          Fileset Description: #{project.friendly_name}
          USRLIBLPPFiles
          Configuration Script: #{project.install_path}/bin/postinstall.sh
          Unconfiguration Script: #{project.install_path}/bin/unpostinstall.sh
          EOUSRLIBLPPFiles
          Bosboot required: N
          License agreement acceptance required: N
          Include license files in this package: N
          Requisites:
            ROOT Part: N
            ROOTFiles
            EOROOTFiles
          USRFiles
      EOF
      tail = <<-EOF.gsub(/^ {8}/, '')
        EOUSRFiles
        EOFileset
      EOF

      File.open '/tmp/bff/gen.preamble', 'w+' do |f|
        f.write preamble
      end

      File.open '/tmp/bff/gen.tail', 'w+' do |f|
        f.write tail
      end

      execute("find #{project.install_dir} -print > /tmp/bff/file.list")
      execute("cat /tmp/bff/gen.preamble /tmp/bff/file.list /tmp/bff/gen.tail > /tmp/bff/gen.template")
    end
  end
end
