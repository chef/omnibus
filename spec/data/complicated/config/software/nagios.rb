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

name "nagios"
default_version "3.3.1"

dependency "gd"
dependency "php"
dependency "spawn-fcgi"

source :url => "http://downloads.sourceforge.net/project/nagios/nagios-3.x/nagios-3.3.1/nagios-3.3.1.tar.gz",
       :md5 => "c935354ce0d78a63bfabc3055fa77ad5"

relative_path "nagios"

env = {
  "LDFLAGS" => "-L#{install_path}/embedded/lib -I#{install_path}/embedded/include",
  "CFLAGS" => "-L#{install_path}/embedded/lib -I#{install_path}/embedded/include",
  "LD_RUN_PATH" => "#{install_path}/embedded/lib"
}

build do
  # configure it
  command(["./configure",
           "--prefix=#{install_path}/embedded/nagios",
           "--with-nagios-user=opscode-nagios",
           "--with-nagios-group=opscode-nagios",
           "--with-command-group=opscode-nagios-cmd",
           "--with-command-user=opscode-nagios-cmd",
           "--with-gd-lib=#{install_path}/embedded/lib",
           "--with-gd-inc=#{install_path}/embedded/include",
           "--with-temp-dir=/var#{install_path}/nagios/tmp",
           "--with-lockfile=/var#{install_path}/nagios/lock",
           "--with-checkresult-dir=/var#{install_path}/nagios/checkresult",
           "--with-mail=/usr/bin/mail"].join(" "),
          :env => env)

  # so dome hacky shit
  command "sed -i 's:for file in includes/rss/\\*;:for file in includes/rss/\\*.\\*;:g' ./html/Makefile"
  command "sed -i 's:for file in includes/rss/extlib/\\*;:for file in includes/rss/extlib/\\*.\\*;:g' ./html/Makefile"
  command "bash -c \"find . -name 'Makefile' | xargs sed -i 's:-o opscode-nagios-cmd -g opscode-nagios-cmd:-o root -g root:g'\""
  command "bash -c \"find . -name 'Makefile' | xargs sed -i 's:-o opscode-nagios -g opscode-nagios:-o root -g root:g'\""

  # build it
  command "make -j #{max_build_jobs} all", :env => { "LD_RUN_PATH" => "#{install_path}/embedded/lib" }
  command "sudo make install"
  command "sudo make install-config"
  command "sudo make install-exfoliation"

  # clean up the install
  command "sudo rm -rf #{install_path}/embedded/nagios/etc/*"
end
