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

name "gd"
default_version "2.0.33"

dependency "libiconv"
dependency "zlib"
dependency "libjpeg"
dependency "libpng"

# TODO: make sure that this is where we want to download libgd from
source :url => "https://bitbucket.org/libgd/gd-libgd/get/GD_2_0_33.tar.gz",
       :md5 => "a028f1642586e611fa39c39175478721"

relative_path "libgd-gd-libgd-486e81dea984"

source_dir = "#{project_dir}/src"

configure_env = {
  "LDFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
  "CFLAGS" => "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include",
  "LD_RUN_PATH" => "#{install_dir}/embedded/lib",
  "LIBS" => "-liconv"
}

build do
  patch :source => 'gd-2.0.33-configure-libpng.patch'
  command(["./configure",
           "--prefix=#{install_dir}/embedded",
           "--with-libiconv-prefix=#{install_dir}/embedded",
           "--with-jpeg=#{install_dir}/embedded",
           "--with-png=#{install_dir}/embedded",
           "--without-x", "--without-freetype",
           "--without-fontconfig",
           "--without-xpm"].join(" "),
          :env => configure_env,
          :cwd => source_dir)

  command "make -j #{workers}", :env => {"LD_RUN_PATH" => "#{install_dir}/embedded/bin", "LIBS" => "-liconv"}, :cwd => source_dir
  command "make install", :cwd => source_dir
end
