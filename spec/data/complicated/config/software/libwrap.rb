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

name "libwrap"
default_version "7.6"

source :url => "ftp://ftp.porcupine.org/pub/security/tcp_wrappers_7.6.tar.gz",
       :md5 => "e6fa25f71226d090f34de3f6b122fb5a"

relative_path "tcp_wrappers_7.6"

########################################################################
#
# libwrap (tcp_wrappers) build instructions pulled from
# http://www.linuxfromscratch.org/blfs/view/6.3/basicnet/tcpwrappers.html
#
########################################################################
#
# patches:
# * shared_lib_plus_plus-1: Required Patch (Fixes some build issues
#   and adds building a shared library)
# * malloc-fix: replaces the `sed` command from the build instructions
#   linked above
# * makefile-dest-fix: patches the makefile to not add "/usr/" to
#   destination dir for library install and doesn't set ownership of
#   the libraries
#

build do
  patch :source => "tcp_wrappers-7.6-shared_lib_plus_plus-1.patch"
  patch :source => "tcp_wrappers-7.6-malloc-fix.patch"
  patch :source => "tcp_wrappers-7.6-makefile-dest-fix.patch"
  command "make STYLE=-DPROCESS_OPTIONS linux"
  command "make DESTDIR=#{install_path}/embedded install-lib"
  command "make DESTDIR=#{install_path}/embedded install-dev"
end
