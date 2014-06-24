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

name "spidermonkey"
default_version "1.8.0"

source :url => "http://ftp.mozilla.org/pub/mozilla.org/js/js-1.8.0-rc1.tar.gz",
       :md5 => "eaad8815dcc66a717ddb87e9724d964e"

relative_path "js"

env = {"LD_RUN_PATH" => "#{install_path}/embedded/lib"}
working_dir = "#{project_dir}/src"

# == Build Notes ==
# The spidermonkey build instructions are copied from here:
# http://wiki.apache.org/couchdb/Installing_SpiderMonkey
#
# These instructions only seem to work with spidermonkey 1.8.0-rc1 and
# earlier. Since couchdb 1.1.1 is compatible with spidermonkey 1.8.5,
# we should eventually invest some time into getting that version built.
#

build do
  command(["make",
           "BUILD_OPT=1",
           "XCFLAGS=-L#{install_path}/embedded/lib -I#{install_path}/embedded/include",
           "-f",
           "Makefile.ref"].join(" "),
          :env => env,
          :cwd => working_dir)
  command(["make",
           "BUILD_OPT=1",
           "JS_DIST=#{install_path}/embedded",
           "-f",
           "Makefile.ref",
           "export"].join(" "),
          :env => env,
          :cwd => working_dir)

  if Ohai.kernel['machine'] =~ /x86_64/
    command "mv #{install_path}/embedded/lib64/libjs.a #{install_path}/embedded/lib"
    command "mv #{install_path}/embedded/lib64/libjs.so #{install_path}/embedded/lib"
  end
  command "rm -rf #{install_path}/embedded/lib64"
end
