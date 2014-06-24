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

name "server-jre"
default_version "7u25"

dependency "rsync"

whitelist_file "jre/bin/javaws"
whitelist_file "jre/bin/policytool"
whitelist_file "jre/lib"
whitelist_file "jre/plugin"
whitelist_file "jre/bin/appletviewer"

if Ohai.kernel['machine'] =~ /x86_64/
  # TODO: download x86 version on x86 machines
  source :url => "http://download.oracle.com/otn-pub/java/jdk/7u25-b15/server-jre-7u25-linux-x64.tar.gz",
         :md5 => "7164bd8619d731a2e8c01d0c60110f80",
         :cookie => 'oraclelicensejre-7u25-oth-JPR=accept-securebackup-cookie;gpw_e24=http://www.oracle.com/technetwork/java/javase/downloads/server-jre7-downloads-1931105.html',
         :warning => "By including the JRE, you accept the terms of the Oracle Binary Code License Agreement for the Java SE Platform Products and JavaFX, which can be found at http://www.oracle.com/technetwork/java/javase/terms/license/index.html"
else
  raise "Server-jre can only be installed on x86_64 systems."
end

relative_path "jdk1.7.0_25"

jre_dir = "#{install_path}/embedded/jre"

build do
  command "mkdir -p #{jre_dir}"
  command "#{install_path}/embedded/bin/rsync -a . #{jre_dir}/"
end
