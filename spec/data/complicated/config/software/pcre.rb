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

name "pcre"
default_version "8.31"

dependency "libedit"
dependency "ncurses"

source :url => "http://iweb.dl.sourceforge.net/project/pcre/pcre/8.31/pcre-8.31.tar.gz",
       :md5 => "fab1bb3b91a4c35398263a5c1e0858c1"

relative_path "pcre-8.31"

configure_env = {
  "CFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include"
}

build do
  command ["./configure",
           "--prefix=#{install_dir}/embedded",
           "--enable-pcretest-libedit"].join(" "), :env => configure_env
  command("make -j #{workers}",
          :env => {
            "PATH" => "#{install_dir}/embedded/bin:#{ENV["PATH"]}"
          })
  command "make install"
end
