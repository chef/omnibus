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

    build do
      shellout! "cd #{install_dirname} && find #{install_basename} -print > #{staging_dir_path('files')}"
      

      write_prototype_content

      write_pkginfo_content

      copy_file("#{project.package_scripts_path}/postinst", staging_dir_path('postinstall'))
      copy_file("#{project.package_scripts_path}/postrm", staging_dir_path('postremove'))

      shellout! "pkgmk -o -r #{install_dirname} -d #{staging_dir} -f #{staging_dir_path('Prototype')}"
      shellout! "pkgchk -vd #{staging_dir} #{project.package_name}"
      shellout! "pkgtrans #{staging_dir} #{package_path} #{project.package_name}"
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
    
    def staging_dir_path(file_name)
      File.join(staging_dir, file_name)
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
      File.open staging_dir_path('Prototype'), 'w+' do |f|
        f.write prototype_content
      end

      # generate the prototype's file list
      shellout! "cd #{install_dirname} && pkgproto < #{staging_dir_path('files')} > #{staging_dir_path('Prototype.files')}"

      # fix up the user and group in the file list to root
      shellout! "awk '{ $5 = \"root\"; $6 = \"root\"; print }' < #{staging_dir_path('Prototype.files')} >> #{staging_dir_path('Prototype')}"
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
      File.open staging_dir_path('pkginfo'), 'w+' do |f|
        f.write pkginfo_content
      end
    end
  end
end
