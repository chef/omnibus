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

name "help2man"
default_version "1.40.5"

source :url => "http://ftp.gnu.org/gnu/help2man/help2man-1.40.5.tar.gz",
       :md5 => "75a7d2f93765cd367aab98986a75f88c"

relative_path "help2man-1.40.5"

build do
  command "./configure --prefix=#{install_path}/embedded"
  command "make"
  command "make install"
end
