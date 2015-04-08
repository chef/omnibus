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
  class Packager::Solaris < Packager::Base
    id :solaris

    setup do
      remove_directory('/tmp/pkgmk')
      create_directory('/tmp/pkgmk')
    end

    build do
      Dir.chdir(staging_dir) do
        shellout! "cd #{install_dirname} && find #{install_basename} -print > /tmp/pkgmk/files"
      end

      write_prototype_content

      write_pkginfo_content

      copy_file("#{project.package_scripts_path}/postinst", '/tmp/pkgmk/postinstall')
      copy_file("#{project.package_scripts_path}/postrm", '/tmp/pkgmk/postremove')

      shellout! "pkgmk -o -r #{install_dirname} -d /tmp/pkgmk -f /tmp/pkgmk/Prototype"
      shellout! "pkgchk -vd /tmp/pkgmk #{project.package_name}"
      abs_package_path = File.absolute_path(package_path) 
      shellout! "pkgtrans /tmp/pkgmk #{abs_package_path} #{project.package_name}"
    end

    # @see Base#package_name
    def package_name
      "#{project.package_name}-#{pkgmk_version}.#{Ohai['kernel']['machine']}.solaris"
    end

    def pkgmk_version
      "#{project.build_version}-#{project.build_iteration}"
    end

    def install_dirname
      File.dirname(project.install_dir)
    end

    def install_basename
      File.basename(project.install_dir)
    end

    #
    # Generate a Prototype file for solaris build
    #
    def write_prototype_content
      prototype_content = <<-EOF.gsub(/^ {8}/, '')
        i pkginfo
        i postinstall
        i postremove
      EOF

      # generate list of control files
      File.open '/tmp/pkgmk/Prototype', 'w+' do |f|
        f.write prototype_content
      end

      Dir.chdir(staging_dir) do
        # generate the prototype's file list
        shellout! "cd #{install_dirname} && pkgproto < /tmp/pkgmk/files > /tmp/pkgmk/Prototype.files"

        # fix up the user and group in the file list to root
        shellout! "awk '{ $5 = \"root\"; $6 = \"root\"; print }' < /tmp/pkgmk/Prototype.files >> /tmp/pkgmk/Prototype"
      end
    end

    #
    # Generate a pkginfo file for solaris build
    #
    def write_pkginfo_content
      pkginfo_content = <<-EOF.gsub(/^ {8}/, '')
        CLASSES=none
        TZ=PST
        PATH=/sbin:/usr/sbin:/usr/bin:/usr/sadm/install/bin
        BASEDIR=#{install_dirname}
        PKG=#{project.package_name}
        NAME=#{project.package_name}
        ARCH=#{`uname -p`.chomp}
        VERSION=#{pkgmk_version}
        CATEGORY=application
        DESC=#{project.description}
        VENDOR=#{project.maintainer}
        EMAIL=#{project.maintainer}
        PSTAMP=#{`hostname`.chomp + Time.now.utc.iso8601}
      EOF
      File.open '/tmp/pkgmk/pkginfo', 'w+' do |f|
        f.write pkginfo_content
      end
    end
  end
end
