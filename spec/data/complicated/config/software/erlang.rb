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

name "erlang"
default_version "R15B03-1"

dependency "zlib"
dependency "openssl"
dependency "ncurses"

version "R15B03-1" do
  source :md5 => 'eccd1e6dda6132993555e088005019f2'
  relative_path "otp_src_R15B03"
end

version "R16B03-1" do
  source md5: 'e5ece977375197338c1b93b3d88514f8'
  relative_path "otp_src_#{version}"
end

source :url => "http://www.erlang.org/download/otp_src_#{version}.tar.gz"

env = {
  "CFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/erlang/include",
  "LDFLAGS" => "-Wl,-rpath #{install_dir}/embedded/lib -L#{install_dir}/embedded/lib -I#{install_dir}/embedded/erlang/include"
}

build do
  # set up the erlang include dir
  command "mkdir -p #{install_dir}/embedded/erlang/include"
  %w{ncurses openssl zlib.h zconf.h}.each do |link|
    command "ln -fs #{install_dir}/embedded/include/#{link} #{install_dir}/embedded/erlang/include/#{link}"
  end

  # TODO: build cross-platform. this is for linux
  command(["./configure",
           "--prefix=#{install_dir}/embedded",
           "--enable-threads",
           "--enable-smp-support",
           "--enable-kernel-poll",
           "--enable-dynamic-ssl-lib",
           "--enable-shared-zlib",
           "--enable-hipe",
           "--without-javac",
           "--with-ssl=#{install_dir}/embedded",
           "--disable-debug"].join(" "),
          :env => env)

  command "make -j #{max_build_jobs}", :env => env
  command "make install"
end
