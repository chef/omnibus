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

name "libgcc"
description "On UNIX systems where we bootstrap a compiler, copy the libgcc"

if (platform == "solaris2" && Omnibus.config.solaris_compiler == "gcc")
  build do
    if File.exists?("/opt/csw/lib/libgcc_s.so.1")
      command "cp /opt/csw/lib/libgcc_s.so.1 #{install_dir}/embedded/lib/"
    else
      raise "cannot find libgcc_s.so.1 -- where is your gcc compiler?"
    end
  end
end

if platform == "aix"
  build do
    if File.exists?("/opt/freeware/lib/pthread/ppc64/libgcc_s.a")
      command "cp -f /opt/freeware/lib/pthread/ppc64/libgcc_s.a #{install_dir}/embedded/lib/"
    else
      raise "cannot find libgcc_s.a -- where is your gcc compiler?"
    end
  end
end

