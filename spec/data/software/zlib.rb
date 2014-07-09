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

name 'zlib'
default_version '1.2.6'

dependency 'libgcc'

version '1.2.6' do
  source md5: '618e944d7c7cd6521551e30b32322f4a'
end

version '1.2.8' do
  source md5: '44d667c142d7cda120332623eab69f40'
end

source url: "http://downloads.sourceforge.net/project/libpng/zlib/#{version}/zlib-#{version}.tar.gz"

relative_path "zlib-#{version}"
configure_env =
  case platform
  when 'aix'
    {
      'CC' => 'xlc -q64',
      'CXX' => 'xlC -q64',
      'LD' => 'ld -b64',
      'CFLAGS' => "-q64 -I#{install_dir}/embedded/include -O",
      'OBJECT_MODE' => '64',
      'ARFLAGS' => '-X64 cru',
      'LDFLAGS' => "-q64 -L#{install_dir}/embedded/lib -Wl,-blibpath:#{install_dir}/embedded/lib:/usr/lib:/lib",
    }
  when 'mac_os_x'
    {
      'LDFLAGS' => "-R#{install_dir}/embedded/lib -L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
      'CFLAGS' => "-I#{install_dir}/embedded/include -L#{install_dir}/embedded/lib",
    }
  when 'solaris2'
    {
      'LDFLAGS' => "-R#{install_dir}/embedded/lib -L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include -static-libgcc",
      'CFLAGS' => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include -DNO_VIZ",
    }
  else
    {
      'LDFLAGS' => "-Wl,-rpath #{install_dir}/embedded/lib -L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
      'CFLAGS' => "-I#{install_dir}/embedded/include -L#{install_dir}/embedded/lib",
    }
  end

build do
  command "./configure --prefix=#{install_dir}/embedded", env: configure_env
  command "make -j #{max_build_jobs}"
  command "make -j #{max_build_jobs} install"
end
