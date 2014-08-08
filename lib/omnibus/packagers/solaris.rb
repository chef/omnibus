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
      purge_directory('/tmp/pkgmk')
    end

    build do
      execute("cd #{install_dirname} && find #{install_basename} -print > /tmp/pkgmk/files")

      write_prototype_content

      write_pkginfo_content

      copy_file("#{project.package_scripts_path}/postinst", '/tmp/pkgmk/postinstall')
      copy_file("#{project.package_scripts_path}/postrm", '/tmp/pkgmk/postremove')

      execute("pkgmk -o -r #{install_dirname} -d /tmp/pkgmk -f /tmp/pkgmk/Prototype")
      execute("pkgchk -vd /tmp/pkgmk #{project.name}")
      execute("pkgtrans /tmp/pkgmk /var/cache/omnibus/pkg/#{package_name} #{project.name}")
    end

    # @see Base#package_name
    def package_name
      "#{project.name}-#{pkgmk_version}.#{Ohai['kernel']['machine']}.solaris"
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

      # generate the prototype's file list
      execute("cd #{install_dirname} && pkgproto < /tmp/pkgmk/files > /tmp/pkgmk/Prototype.files")

      # fix up the user and group in the file list to root
      execute("awk '{ $5 = \"root\"; $6 = \"root\"; print }' < /tmp/pkgmk/Prototype.files >> /tmp/pkgmk/Prototype")
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
        PKG=#{project.name}
        NAME=#{project.name}
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
