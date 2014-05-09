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

name "rubygems"
default_version "1.8.24"

dependency "ruby"

version "1.8.24" do
  source md5: "3a555b9d579f6a1a1e110628f5110c6b"
end

version "2.2.1" do
  source md5: "1f0017af0ad3d3ed52665132f80e7443"
end

source url: "http://production.cf.rubygems.org/rubygems/rubygems-#{version}.tgz"

relative_path "rubygems-#{version}"

build do
  ruby "setup.rb"
end
