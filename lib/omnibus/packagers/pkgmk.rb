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
  # Builds a pkgmk package (.solaris extention)
  #
  class Packager::Pkgmk < Packager::Base

    validate do
      # nothing
    end

    setup do
      purge_directory(staging_dir)
      purge_directory(Config.package_dir)
      purge_directory(staging_resources_path)
      copy_directory(resources_path, staging_resources_path)
      purge_directory('/tmp/pkgmk')
    end

    build do
      execute("cd #{install_dirname} && find #{install_basename} -print > /tmp/pkgmk/files")

      File.open '/tmp/pkgmk/Prototype', 'w+' do |f|
        f.write prototype_content
      end

      # generate the prototype's file list
      execute("cd #{install_dirname} && pkgproto < /tmp/pkgmk/files > /tmp/pkgmk/Prototype.files")

      # fix up the user and group in the file list to root
      execute("awk '{ $5 = \"root\"; $6 = \"root\"; print }' < /tmp/pkgmk/Prototype.files >> /tmp/pkgmk/Prototype")

      File.open '/tmp/pkgmk/pkginfo', 'w+' do |f|
        f.write pkginfo_content
      end

      copy_file("#{project.package_scripts_path}/postinst", '/tmp/pkgmk/postinstall')
      copy_file("#{project.package_scripts_path}/postrm", '/tmp/pkgmk/postremove')

      execute("pkgmk -o -r #{install_dirname} -d /tmp/pkgmk -f /tmp/pkgmk/Prototype")
      execute('pkgchk -vd /tmp/pkgmk chef')
      execute("pkgtrans /tmp/pkgmk /var/cache/omnibus/pkg/#{package_name} chef")
    end

    clean do
      # nothing
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

    def prototype_content
      prototype_content = <<-EOF
i pkginfo
i postinstall
i postremove
      EOF
    end

    def pkginfo_content
      pkginfo_content = <<-EOF
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
    end
  end
end
