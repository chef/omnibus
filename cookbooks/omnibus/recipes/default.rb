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
directory Chef::Config[:file_cache_path] do
  recursive true
  action :create
end

case node['platform_family']
when "debian"
  include_recipe "apt"
when "rhel"
  include_recipe "yum::epel"
when "solaris2"
  include_recipe "opencsw"
  include_recipe "solaris_omgwtfbbq"
end

include_recipe "build-essential"
include_recipe "git"

# install ruby and symlink the binaries to /usr/local
include_recipe "ruby_1.9"
%w{ruby gem rake bundle fpm ronn}.each do |bin|
  link "/usr/local/bin/#{bin}" do
    to "/opt/ruby1.9/bin/#{bin}"
  end
end

# install the packaging related packages
package_pkgs = value_for_platform_family(
  "debian" => ["dpkg-dev"],
  "rhel" => ["rpm-build"],
  "default" => []
)
package_pkgs.each do |pkg|
  package pkg do
    action :install
  end
end

# install the libxml / libxslt packages
xml_pkgs = value_for_platform_family(
  "debian" => ["libxml2", "libxml2-dev", "libxslt1.1", "libxslt1-dev"],
  "rhel" => ["libxml2", "libxml2-devel", "libxslt", "libxslt-devel"],
  "default" => []
)
xml_pkgs.each do |pkg|
  package pkg do
    action :install
  end
end

case node['platform_family']
when "solaris2"

  %w{libxml2_dev libxslt_dev libssl_dev libyaml libtool help2man ggettext texinfo}.each do |pkg|
    opencsw pkg
  end

  link "/opt/csw/bin/gettext" do
    to "/opt/csw/bin/gettext"
  end

else

  %w{libtool help2man gettext texinfo}.each do |name|
    package name
  end

  # Turn off strict host key checking for github
  execute "disable-host-key-checking-github" do
    command "echo '\nHost github.com\n\tStrictHostKeyChecking no' >> /etc/ssh/ssh_config"
    not_if "cat /etc/ssh/ssh_config | grep github.com"
    only_if { ::File.exists?("/etc/ssh/ssh_config") }
  end
  # Ensure SSH_AUTH_SOCK is honored under sudo
  execute "make-sudo-honor-ssh_auth_sock" do
    command "echo '\nDefaults env_keep+=SSH_AUTH_SOCK' >> /etc/sudoers"
    not_if "cat /etc/sudoers | grep SSH_AUTH_SOCK"
    only_if { ::File.exists?("/etc/sudoers") }
  end

end

case node['platform_family']
when "debian", "rhel"

  include_recipe "python"

  python_pip "Sphinx" do
    version "1.1.3"
    action :install
  end

  python_pip "Pygments" do
    version "1.4"
    action :install
  end
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
