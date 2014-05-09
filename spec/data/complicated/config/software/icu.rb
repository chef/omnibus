#
# Copyright:: Copyright (c) 2012-2014 Chef Software, Inc.
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

name "icu"
default_version "4.8.1.1"

source :url => "http://download.icu-project.org/files/icu4c/4.8.1.1/icu4c-4_8_1_1-src.tgz",
:md5 => "ea93970a0275be6b42f56953cd332c17"

relative_path "icu"

working_dir = "#{project_dir}/source"

build do
  command("./configure --prefix=#{install_dir}/embedded",
          :env => {
            "CFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include"
          },
          :cwd => working_dir)
  command("make -j #{max_build_jobs}",
          :env => {
            "LD_RUN_PATH" => "#{install_dir}/embedded/lib"
          },
          :cwd => working_dir)
  command "make install", :cwd => working_dir
end
