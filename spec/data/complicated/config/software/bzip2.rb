#
# Copyright:: Copyright (c) 2013-2014 Chef Software, Inc.
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
# Install bzip2 and its shared library, libbz2.so
# This library object is required for building Python with the bz2 module,
# and should be picked up automatically when building Python.

name "bzip2"
default_version "1.0.6"

dependency "zlib"
dependency "openssl"

source :url => "http://www.bzip.org/#{version}/#{name}-#{version}.tar.gz",
       :md5 => "00b516f4704d4a7cb50a1d97e6e8e15b"

relative_path "#{name}-#{version}"

prefix="#{install_path}/embedded"
libdir="#{prefix}/lib"

env = {
  "LDFLAGS" => "-L#{libdir} -I#{prefix}/include",
  "CFLAGS" => "-L#{libdir} -I#{prefix}/include -fPIC",
  "LD_RUN_PATH" => libdir
}

build do
  patch :source => 'makefile_take_env_vars.patch'
  command "make PREFIX=#{prefix} VERSION=#{version}", :env => env
  command "make PREFIX=#{prefix} VERSION=#{version} -f Makefile-libbz2_so", :env => env
  command "make install VERSION=#{version} PREFIX=#{prefix}", :env => env
end
