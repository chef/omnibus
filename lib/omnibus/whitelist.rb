
# Copyright 2012-2020, Chef Software Inc.
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

WHITELIST_LIBS = [
    /ld-linux/,
    /libanl\.so/,
    /libc\.so/,
    /libcrypt\.so/,
    /libdl/,
    /libfreebl\d\.so/,
    /libgcc_s\.so/,
    /libm\.so/,
    /libnsl\.so/,
    /libpthread/,
    /libresolv\.so/,
    /librt\.so/,
    /libstdc\+\+\.so/,
    /libutil\.so/,
    /linux-vdso.+/,
    /linux-gate\.so/,
  ].freeze

ARCH_WHITELIST_LIBS = [
  /libanl\.so/,
  /libc\.so/,
  /libcrypt\.so/,
  /libdb-5\.3\.so/,
  /libdl\.so/,
  /libffi\.so/,
  /libgdbm\.so/,
  /libm\.so/,
  /libnsl\.so/,
  /libpthread\.so/,
  /librt\.so/,
  /libutil\.so/,
].freeze

AIX_WHITELIST_LIBS = [
  /libpthread\.a/,
  /libpthreads\.a/,
  /libdl.a/,
  /librtl\.a/,
  /libc\.a/,
  /libcrypt\.a/,
  /unix$/,
].freeze

SOLARIS_WHITELIST_LIBS = [
  /libaio\.so/,
  /libavl\.so/,
  /libcrypt_[di]\.so/,
  /libcrypto.so/,
  /libcurses\.so/,
  /libdoor\.so/,
  /libgen\.so/,
  /libmd5\.so/,
  /libmd\.so/,
  /libmp\.so/,
  /libresolv\.so/,
  /libscf\.so/,
  /libsec\.so/,
  /libsocket\.so/,
  /libssl.so/,
  /libthread.so/,
  /libuutil\.so/,
  /libkstat\.so/,
  # solaris 11 libraries:
  /libc\.so\.1/,
  /libm\.so\.2/,
  /libdl\.so\.1/,
  /libnsl\.so\.1/,
  /libpthread\.so\.1/,
  /librt\.so\.1/,
  /libcrypt\.so\.1/,
  /libgdbm\.so\.3/,
  /libgcc_s\.so\.1/,
  /libcryptoutil\.so\.1/,
  /libucrypto\.so\.1/,
  /libz\.so\.1/, # while we package our own libz, this get dragged along from Solaris 11's libelf library for some reason...
  /libelf\.so\.1/,
  /libssp\.so\.0/,
  # solaris 9 libraries:
  /libm\.so\.1/,
  /libc_psr\.so\.1/,
  /s9_preload\.so\.1/,
].freeze

SMARTOS_WHITELIST_LIBS = [
  /libm.so/,
  /libpthread.so/,
  /librt.so/,
  /libsocket.so/,
  /libdl.so/,
  /libnsl.so/,
  /libgen.so/,
  /libmp.so/,
  /libmd.so/,
  /libc.so/,
  /libgcc_s.so/,
  /libstdc\+\+\.so/,
  /libcrypt.so/,
  /libcrypto.so/,
  /libssl.so/,
  /libssp\.so/,
  /libumem\.so/,
  /libffi\.so/,
  /libz\.so/, # while we package our own libz, this get dragged along from Solaris 11's libelf library for some reason...
].freeze

MAC_WHITELIST_LIBS = [
  /libobjc\.A\.dylib/,
  /libSystem\.B\.dylib/,
  /CoreFoundation/,
  /CoreServices/,
  /Tcl$/,
  /Cocoa$/,
  /Carbon$/,
  /Foundation/,
  /IOKit$/,
  /Tk$/,
  /libutil\.dylib/,
  /libffi\.dylib/,
  /libncurses\.5\.4\.dylib/,
  /libiconv/,
  /libidn2\.0\.dylib/,
  /libstdc\+\+\.6\.dylib/,
  /libc\+\+\.1\.dylib/,
  /libc\+\+\.1\.dylib/,
  /libzstd\.1\.dylib/,
  /Security/,
].freeze

FREEBSD_WHITELIST_LIBS = [
  /libc\.so/,
  /libgcc_s\.so/,
  /libcrypt\.so/,
  /libm\.so/,
  /librt\.so/,
  /libthr\.so/,
  /libutil\.so/,
  /libelf\.so/,
  /libkvm\.so/,
  /libprocstat\.so/,
  /libmd\.so/,
].freeze

IGNORED_ENDINGS = %w{
  .TXT
  .[ch]
  .[ch]pp
  .[eh]rl
  .app
  .appup
  .bat
  .beam
  .cc
  .cmake
  .conf
  .css
  .e*rb
  .feature
  .gemspec
  .gif
  .gitignore
  .gitkeep
  .h*h
  .jar
  .java
  .jpg
  .js
  .jsm
  .json
  .lock
  .log
  .lua
  .md
  .mkd
  .npmignore
  .out
  .packlist
  .perl
  .pl
  .pm
  .png
  .pod
  .properties
  .py[oc]*
  .r*html
  .rake
  .rdoc
  .ri
  .rst
  .scss
  .sh
  .sql
  .svg
  .toml
  .ttf
  .txt
  .xml
  .yml
  Gemfile
  LICENSE
  Makefile
  README
  Rakefile
  VERSION
  license
}.freeze

IGNORED_PATTERNS = %w{
  /build_info/
  /licenses/
  /LICENSES/
  /man/
  /share/doc/
  /share/info/
  /share/postgresql/
  /share/terminfo/
  /share/timezone/
  /terminfo/
}.freeze
