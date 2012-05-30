#
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

# apt-get update -y
# apt-get -y install build-essential binutils-doc autoconf flex bison git-core openjdk-6-jdk default-jdk ruby ruby1.8 ruby1.8-dev rdoc1.8 irb1.8 ri1.8 libopenssl-ruby1.8 rubygems libtool dpkg-dev libxml2 libxml2-dev libxslt1.1 libxslt1-dev help2man gettext texinfo
# update-java-alternatives -s java-6-openjdk
# gem install fpm ohai --no-rdoc --no-ri
# ln -s /var/lib/gems/1.8/bin/* /usr/local/bin

# make certain our chef-solo cache dir exists
directory "#{Chef::Config[:file_cache_path]}" do
  action :create
end

case node['platform']
when "ubuntu"
  include_recipe "apt"
when "centos"
  include_recipe "yum"
end

include_recipe "build-essential"
include_recipe "git"
include_recipe "python"

# install ruby and symlink the binaries to /usr/local
include_recipe "ruby_1.9"
%w{ruby gem rake bundle fpm}.each do |bin|
  link "/usr/local/bin/#{bin}" do
    to "/opt/ruby1.9/bin/#{bin}"
  end
end

# install the packaging related packages
package_pkgs = value_for_platform(
  ["ubuntu"] => {
    "default" => ["dpkg-dev"]
  },
  ["centos"] => {
    "default" => ["rpm-build"]
  },
  ["mac_os_x"] => {
    "default" => [],
  }
)
package_pkgs.each do |pkg|
  package pkg do
    action :install
  end
end

# install the libxml / libxslt packages
xml_pkgs = value_for_platform(
  ["ubuntu"] => {
    "default" => ["libxml2", "libxml2-dev", "libxslt1.1", "libxslt1-dev"]
  },
  ["centos"] => {
    "default" => ["libxml2", "libxml2-devel", "libxslt", "libxslt-devel"]
  },
  ["mac_os_x"] => {
    "default" => [],
  }
)
xml_pkgs.each do |pkg|
  package pkg do
    action :install
  end
end

%w{libtool help2man gettext texinfo}.each do |name|
  package name
end

bash "install python packages" do
  code <<BASH
pip install Sphinx==1.1.2
pip install Pygments==1.4
BASH
end

node['omnibus']['install-dirs'].each do |d|
  directory d do
    mode "755"
    owner node["omnibus"]["build-user"]
    recursive true
  end
end

directory "/var/cache/omnibus" do
  mode "755"
  owner node["omnibus"]["build-user"]
  recursive true
end

