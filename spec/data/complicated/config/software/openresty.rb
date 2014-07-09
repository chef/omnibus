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

name "openresty"
default_version "1.4.3.6"

dependency "pcre"
dependency "openssl"
dependency "zlib"

source :url => "http://openresty.org/download/ngx_openresty-#{version}.tar.gz",
       :md5 => "5e5359ae3f1b8db4046b358d84fabbc8"

relative_path "ngx_openresty-#{version}"

build do
  env = {
    "LDFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
    "CFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
    "LD_RUN_PATH" => "#{install_dir}/embedded/lib"
  }

  command ["./configure",
           "--prefix=#{install_dir}/embedded",
           "--sbin-path=#{install_dir}/embedded/sbin/nginx",
           "--conf-path=#{install_dir}/embedded/conf/nginx.conf",
           "--with-http_ssl_module",
           "--with-debug",
           "--with-http_stub_status_module",
           # Building Nginx with non-system OpenSSL
           # http://www.ruby-forum.com/topic/207287#902308
           "--with-ld-opt=\"-L#{install_dir}/embedded/lib -Wl,-rpath,#{install_dir}/embedded/lib -lssl -lcrypto -ldl -lz\"",
           "--with-cc-opt=\"-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include\"",
           # Options inspired by the OpenResty Cookbook
           '--with-md5-asm',
           '--with-sha1-asm',
           '--with-pcre-jit',
           '--with-luajit',
           '--without-http_ssi_module',
           '--without-mail_smtp_module',
           '--without-mail_imap_module',
           '--without-mail_pop3_module',
           '--with-ipv6',
           # AIO support define in Openresty cookbook. Requires Kernel >= 2.6.22
           # Ubuntu 10.04 reports: 2.6.32-38-server #83-Ubuntu SMP
           # However, they require libatomic-ops-dev and libaio
           #'--with-file-aio',
           #'--with-libatomic'
          ].join(" "), :env => env

  command "make -j #{max_build_jobs}", :env => env
  command "make install"
end
