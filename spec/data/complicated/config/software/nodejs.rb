#
# Copyright:: Copyright (c) 2013-2014 Chef Software, Inc.
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

name "nodejs"
default_version "0.10.10"

version "0.10.10" do
  source :md5 => "a47a9141567dd591eec486db05b09e1c"
end

version "0.10.26" do
  source :md5 => "15e9018dadc63a2046f61eb13dfd7bd6"
end

source :url => "http://nodejs.org/dist/v#{version}/node-v#{version}.tar.gz"

relative_path "node-v#{version}"

# Ensure we run with Python 2.6 on Redhats < 6
if OHAI['platform_family'] == "rhel" && OHAI['platform_version'].to_f < 6
  python = 'python26'
else
  python = 'python'
end

build do
  command "#{python} ./configure --prefix=#{install_dir}/embedded"
  command "make -j #{max_build_jobs}"
  command "make install"
end
