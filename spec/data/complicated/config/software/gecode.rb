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

name "gecode"
default_version "3.7.3"

source :url => "http://www.gecode.org/download/gecode-3.7.3.tar.gz",
       :md5 => "7a5cb9945e0bb48f222992f2106130ac"

relative_path "gecode-3.7.3"

test = Mixlib::ShellOut.new("test -f /usr/bin/gcc44")
test.run_command

configure_env = if test.exitstatus == 0
                  {"CC" => "gcc44", "CXX" => "g++44"}
                else
                  {}
                end

build do
  command(["./configure",
           "--prefix=#{install_dir}/embedded",
           "--disable-doc-dot",
           "--disable-doc-search",
           "--disable-doc-tagfile",
           "--disable-doc-chm",
           "--disable-doc-docset",
           "--disable-qt",
           "--disable-examples"].join(" "),
          :env => configure_env)
  command "make -j #{max_build_jobs}", :env => { "LD_RUN_PATH" => "#{install_dir}/embedded/lib" }
  command "make install"
end
