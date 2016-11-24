#
# Copyright 2016 Chef Software, Inc.
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
  class Packager::Pkgsrc < Packager::Base
    id :pkgsrc

    PKGTOOLS_VERSION = "20091115".freeze

    POSTINST = "${project.package_scripts_path}/postinst".freeze
    POSTRM = "${project.package_scripts_path}/postrm".freeze
    BUILD_INFO = staging_dir_path("build-info").freeze
    COMMENT_FILE = staging_dir_path("comment").freeze
    PACK_LIST = staging_dir_path('packlist').freeze

    build do
      write_buildinfo
      write_comment
      write_packlist
      create_pkg
    end

    def create_pkg
      shellout! "pkg_create -B #{BUILD_INFO} -c #{COMMENT_FILE} -d #{COMMENT_FILE} -f #{PACK_LIST} -I #{project.install_dir} -U #{pkg_name}.tgz" 
    end

    def pkg_name
      "#{project.package_name}-#{project.build_version}-#{project.build_iteration}"
    end

    def write_buildinfo
      buildinfo_content <<-EOF
        MACHINE_ARCH=#{safe_architecture}
        OPSYS=#{opsys}
        OS_VERSION=#{os_version}
        PKGTOOLS_VERSION=#{PKGTOOLS_VERSION}
      EOF

      File.open(BUILD_INFO, "w+") do |f|
        f.write(buildinfo_content)
      end
    end

    def write_comment
      File.open(COMMENT_FILE, "w+") do |f|
        f.write(project.description)
      end
    end

    def write_packlist
      shellout! "cd #{install_dirname} && find #{install_basename} -type l -or -type f -print | sort > #{PACK_LIST}"
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
