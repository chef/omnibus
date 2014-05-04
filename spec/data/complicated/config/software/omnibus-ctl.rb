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

name "omnibus-ctl"
default_version "0.0.7"

dependency "ruby"
dependency "rubygems"
dependency "bundler"

source :git => "git://github.com/opscode/omnibus-ctl.git"

relative_path "omnibus-ctl"

build do
  gem "build omnibus-ctl.gemspec"
  gem "install omnibus-ctl-#{version}.gem"
  command "mkdir -p #{install_dir}/embedded/service/omnibus-ctl"
  command "touch #{install_dir}/embedded/service/omnibus-ctl/.gitkeep"
end

