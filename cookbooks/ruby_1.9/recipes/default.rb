#
# Author::        Stephen Delano
# Copyright:: Copyright (c) 2012 Opscode, Inc.
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
# -*- coding: utf-8 -*-
#

include_recipe "build-essential"

# fix yaml and ensure ruby1.9 builds with openssl gem
case node[:platform]
when "ubuntu", "debian"
  package "libtool"
  package "libyaml-dev"
  package "libssl-dev"
when "centos", "redhat"
  package "libtool"
  package "libyaml-devel"
  package "openssl-devel"
end

# Download the ruby source for 1.9.3. Skip the download if:
# * the source file already exists
# * ruby 1.9.3 has been installed at the specified patch-level
#
remote_file "/tmp/ruby-1.9.3-p194.tar.gz" do
  source "http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.3-p194.tar.gz"
  not_if do
    ::File.exists?("/tmp/ruby-1.9.3-p194.tar.gz") ||
      (::File.exists?("/opt/ruby1.9/bin/ruby") &&
       system("/opt/ruby1.9/bin/ruby --version | grep -q '1.9.3p194'"))
  end
end

# Install ruby from source unless it already exists at the correct
# version
#
execute "install ruby-1.9.3" do
  cwd "/tmp"
  command <<-EOH
tar zxf ruby-1.9.3-p194.tar.gz
cd ruby-1.9.3-p194
./configure --prefix=/opt/ruby1.9
make
make install
EOH
  environment(
    'CFLAGS' => '-L/usr/lib -I/usr/include',
    'LDFLAGS' => '-L/usr/lib -R/usr/lib -I/usr/include'
  )
  not_if do
    ::File.exists?("/opt/ruby1.9/bin/ruby") &&
      system("/opt/ruby1.9/bin/ruby --version | grep -q '1.9.3p194'")
  end
end

gem_package "1.9-bundler" do
  package_name "bundler"
  version "1.0.18"
  gem_binary "/opt/ruby1.9/bin/gem"
end
