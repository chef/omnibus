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

name "pip"
default_version "1.3"

dependency "setuptools"

source :url => "https://pypi.python.org/packages/source/p/pip/pip-#{version}.tar.gz",
       :md5 => '918559b784e2aca9559d498050bb86e7'

relative_path "pip-#{version}"

build do
  command "#{install_path}/embedded/bin/python setup.py install --prefix=#{install_path}/embedded"
end
