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

name "popt"
default_version "1.16"

source :url => "http://rpm5.org/files/popt/popt-1.16.tar.gz",
       :md5 => "3743beefa3dd6247a73f8f7a32c14c33"

relative_path "popt-1.16"

env =
  case platform
  when "solaris2"
    {
      "LDFLAGS" => "-L#{install_path}/embedded/lib -I#{install_path}/embedded/include",
      "CFLAGS" => "-L#{install_path}/embedded/lib -I#{install_path}/embedded/include",
      "LD_RUN_PATH" => "#{install_path}/embedded/lib"
    }
  else
    {
      "LDFLAGS" => "-L#{install_path}/embedded/lib -I#{install_path}/embedded/include",
      "CFLAGS" => "-L#{install_path}/embedded/lib -I#{install_path}/embedded/include",
      "LD_RUN_PATH" => "#{install_path}/embedded/lib"
    }
  end

build do
  # --disable-nls => Disable localization support.
  command "./configure --prefix=#{install_path}/embedded --disable-nls", :env => env
  command "make -j #{max_build_jobs}", :env => env
  command "make install"
end
