#
# Copyright 2016-2018 Chef Software, Inc.
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
  class Packager::PKGSRC < Packager::Base
    id :pkgsrc

    PKGTOOLS_VERSION = "20091115".freeze

    build do
      write_buildinfo
      write_buildver
      write_comment
      write_packlist
      create_pkg
    end

    def build_info
      staging_dir_path("build-info")
    end

    def build_ver
      staging_dir_path("build-ver")
    end

    def comment_file
      staging_dir_path("comment")
    end

    def pack_list
      staging_dir_path("packlist")
    end

    def create_pkg
      postinst = "#{project.package_scripts_path}/postinst"
      postrm = "#{project.package_scripts_path}/postrm"

      shellout! "cd #{Config.package_dir} && pkg_create -i #{postinst} -k #{postrm} -p  #{project.install_dir} -b #{build_ver} -B #{build_info} -c #{comment_file} -d #{comment_file} -f #{pack_list} -I #{project.install_dir} -l -U #{package_name}"
    end

    def package_name
      "#{project.package_name}-#{project.build_version}.tgz"
    end

    def write_buildver
      File.open build_ver, "w+" do |f|
        f.write"#{project.build_version}-#{project.build_iteration}"
      end
    end

    def write_buildinfo
      buildinfo_content = <<~EOF
        MACHINE_ARCH=#{safe_architecture}
        OPSYS=#{opsys}
        OS_VERSION=#{os_version}
        PKGTOOLS_VERSION=#{PKGTOOLS_VERSION}
      EOF

      File.open(build_info, "w+") do |f|
        f.write(buildinfo_content)
      end
    end

    def write_comment
      File.open(comment_file, "w+") do |f|
        f.write(project.description)
      end
    end

    def write_packlist
      File.open pack_list, "w+" do |f|
        f.write "@pkgdir #{project.install_dir}\n@cwd #{project.install_dir}/\n"
      end

      shellout! "cd #{project.install_dir} && find . -type l -or -type f | sort >> #{pack_list}"
    end

    def opsys
      Ohai["kernel"]["name"]
    end

    def os_version
      Ohai["kernel"]["release"]
    end

    def safe_architecture
      if smartos?
        if Ohai["kernel"]["update"] == "86_64"
          "x86_64"
        else
          "i386"
        end
      else
        # FIXME: this undoubtedly will need filling out once we make this go for platforms that aren't SmartOS
        Ohai["kernel"]["machine"]
      end
    end
  end
end
