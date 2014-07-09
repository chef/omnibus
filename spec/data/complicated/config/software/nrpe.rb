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

name "nrpe"
default_version "2.13"

dependency "zlib"
dependency "openssl"
dependency "libwrap"

# tarball location comes from sourceforge download redirect
source :url => "http://downloads.sourceforge.net/project/nagios/nrpe-2.x/nrpe-2.13/nrpe-2.13.tar.gz",
       :md5 => "e5176d9b258123ce9cf5872e33a77c1a"

relative_path "nrpe-2.13"

env = {
  "LDFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
  "CFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
  "LD_RUN_PATH" => "#{install_dir}/embedded/lib",
  "PATH" => "#{install_dir}/embedded/bin:#{ENV["PATH"]}"
}

build do
  # TODO: OMG THIS IS HORRIBLE
  command "sed -i 's:\\r::g' ./src/nrpe.c"

  patch :source => "fix_for_runit.patch",
        :target => "./src/nrpe.c"

  # configure it
  command(["./configure",
           "--prefix=#{install_dir}/embedded",
           "--with-ssl=#{install_dir}/embedded",
           "--with-ssl-lib=#{install_dir}/embedded/lib",
           "--with-ssl-inc=#{install_dir}/embedded/include"].join(" "),
          :env => env)

  # build it
  command "make all", :env => {"LD_RUN_PATH" => "#{install_dir}/embedded/lib"}

  # move it
  command "mkdir -p #{install_dir}/embedded/nagios/libexec"
  command "mkdir -p #{install_dir}/embedded/nagios/bin"
  command "cp ./src/check_nrpe #{install_dir}/embedded/nagios/libexec"
  command "sudo cp ./src/nrpe #{install_dir}/embedded/nagios/bin"
end
