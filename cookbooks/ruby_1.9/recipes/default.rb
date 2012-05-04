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

# ensure ruby1.9 builds with openssl gem
case node[:platform]
when "ubuntu", "debian"
  package "libssl-dev"
end

# Download the ruby source for 1.9.2. Skip the download if:
# * the source file already exists
# * ruby 1.9.2 has been installed at the specified patch-level
#
remote_file "/tmp/ruby-1.9.3-p320.tar.gz" do
  source "http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.2-p320.tar.gz"
  not_if do
    ::File.exists?("/tmp/ruby-1.9.3-p320.tar.gz") ||
      (::File.exists?("/opt/ruby1.9/bin/ruby") &&
       system("/opt/ruby1.9/bin/ruby --version | grep -q '1.9.3p320'"))
  end
end

# Install ruby from source unless it already exists at the correct
# version
#
bash "install ruby-1.9.2" do
  cwd "/tmp"
  code <<-EOH
tar zxf ruby-1.9.3-p320.tar.gz
cd ruby-1.9.3-p320
./configure --prefix=/opt/ruby1.9
make
make install
EOH
  not_if do
    ::File.exists?("/opt/ruby1.9/bin/ruby") &&
      system("/opt/ruby1.9/bin/ruby --version | grep -q '1.9.2p180'")
  end
end

# Download the source for Rubygems 1.8.5 unless:
# * the source file already exists
# * rubygems 1.8.5 is installed to ruby 1.9.2
#

rubygems_version = "1.8.12"

remote_file "/tmp/rubygems-#{rubygems_version}.tgz" do
  source "http://production.cf.rubygems.org/rubygems/rubygems-#{rubygems_version}.tgz"
  not_if do
    ::File.exists?("/tmp/rubygems-#{rubygems_version}.tgz") ||
      (::File.exists?("/opt/ruby1.9/bin/gem") &&
       system("/opt/ruby1.9/bin/gem --version | grep -q '#{rubygems_version}'"))
  end
end

# Install rubygems from source only if we need to
#
bash "install rubygems-#{rubygems_version} on ruby-1.9.2" do
  cwd "/tmp"
  code <<-EOH
tar zxf rubygems-#{rubygems_version}.tgz
cd rubygems-#{rubygems_version}
/opt/ruby1.9/bin/ruby setup.rb --no-rdoc --no-ri
EOH
  not_if do
    ::File.exists?("/opt/ruby1.9/bin/gem") &&
      system("/opt/ruby1.9/bin/gem --version | grep -q '#{rubygems_version}'")
  end
end

gem_package "1.9-bundler" do
  package_name "bundler"
  version "1.0.18"
  gem_binary "/opt/ruby1.9/bin/gem"
end
