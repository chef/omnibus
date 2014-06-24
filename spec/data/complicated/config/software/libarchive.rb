#
# Copyright:: Copyright (c) 2014 Chef Software, Inc.
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

# A requirement for api.berkshelf.com that is used in berkshelf specs
# https://github.com/berkshelf/api.berkshelf.com

name "libarchive"
default_version "3.1.2"

source :url => "http://www.libarchive.org/downloads/libarchive-#{version}.tar.gz",
  :md5 => 'efad5a503f66329bb9d2f4308b5de98a'

relative_path "libarchive-#{version}"

env = {
  "LDFLAGS" => "-L#{install_path}/embedded/lib -I#{install_path}/embedded/include",
  "CFLAGS" => "-L#{install_path}/embedded/lib -I#{install_path}/embedded/include "
}

build do
  command "./configure --prefix=#{install_path}/embedded \
    --without-lzma \
    --without-lzo2 \
    --without-nettle \
    --without-xml2 \
    --without-expat \
    --without-bz2lib \
    --without-iconv \
    --without-zlib \
    --disable-bsdtar \
    --disable-bsdcpio \
    --without-lzmadec \
    --without-openssl", :env => env
  command "make", :env => env
  command "make install", :env => env
end
