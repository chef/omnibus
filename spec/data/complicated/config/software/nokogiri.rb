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

name "nokogiri"
default_version "1.6.1"

if platform == 'windows'
  dependency "ruby-windows"
  dependency "ruby-windows-devkit"
else
  dependency "ruby"
  dependency "rubygems"
  dependency "libxml2"
  dependency "libxslt"
  dependency "libiconv"
  dependency "zlib"
end

# nokogiri uses pkg-config, and on a mac that will find the system pkg-config
# which will find the system pkg-configs which will pull in libicucore from the
# libxml2 pkg-config spec.  override pkg-configs path here to point into our
# /opt/chef/embedded pkg-configs.  this should probably be done more generally,
# in core ominbus-ruby.
env = {
  "PKG_CONFIG_PATH" => "#{install_dir}/embedded/lib/pkgconfig",
  "NOKOGIRI_USE_SYSTEM_LIBRARIES" => "true",
}

build do
  gem ["install",
       "nokogiri",
       "-v #{version}",
       "--",
       "--use-system-libraries",
       "--with-xml2-lib=#{install_dir}/embedded/lib",
       "--with-xml2-include=#{install_dir}/embedded/include/libxml2",
       "--with-xslt-lib=#{install_dir}/embedded/lib",
       "--with-xslt-include=#{install_dir}/embedded/include/libxslt",
       "--with-iconv-dir=#{install_dir}/embedded",
       "--with-zlib-dir=#{install_dir}/embedded"].join(" "), :env => env
end
