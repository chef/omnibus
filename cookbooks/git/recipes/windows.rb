#
# Cookbook Name:: git
# Recipe:: windows
#
# Copyright 2008-2012, Opscode, Inc.
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

file_name = 'Git-1.7.11-preview20120710.exe'
file_checksum = 'cc84132e0acc097fc42a9370214a9ce0ff942e1a8237f11d8cb051cb6043e0d5'

remote_file "#{Chef::Config[:file_cache_path]}/#{file_name}" do
  source "http://msysgit.googlecode.com/files/#{file_name}"
  checksum file_checksum
  not_if { File.exists?("#{Chef::Config[:file_cache_path]}/#{file_name}") }
end

windows_batch "install git" do
  command "#{Chef::Config[:file_cache_path]}/#{file_name} /verysilent /dir=C:\\git"
  creates "C:\\git\\cmd\\git.exe"
end

windows_path "C:\\git\\cmd" do
  action :add
end
