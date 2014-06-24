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

name "fcgi"
default_version "2.4.0"

dependency "autoconf"
dependency "automake"
dependency "libtool"

source :url => "http://fastcgi.com/dist/fcgi-2.4.0.tar.gz",
       :md5 => "d15060a813b91383a9f3c66faf84867e"

relative_path "fcgi-2.4.0"

reconf_env = {"PATH" => "#{install_path}/embedded/bin:#{ENV["PATH"]}"}

configure_env = {
  "LDFLAGS" => "-L#{install_path}/embedded/lib -I#{install_path}/embedded/include -L/lib -L/usr/lib",
  "CFLAGS" => "-L#{install_path}/embedded/lib -I#{install_path}/embedded/include",
  "LD_RUN_PATH" => "#{install_path}/embedded/lib",
  "PATH" => "#{install_path}/embedded/bin:#{ENV["PATH"]}"
}

build do
  # patch and touch files so it builds
  diff = <<D
24a25
> #include <cstdio>
D
  command "echo '#{diff}' | patch libfcgi/fcgio.cpp"
  command "touch COPYING ChangeLog AUTHORS NEWS"

  # autoreconf
  command "autoreconf -i -f", :env => reconf_env
  command "libtoolize", :env => reconf_env

  # configure and build
  command "./configure --prefix=#{install_path}/embedded", :env => configure_env
  command "make -j #{max_build_jobs}", :env => {"LD_RUN_PATH" => "#{install_path}/embedded/lib"}
  command "make install"
end
