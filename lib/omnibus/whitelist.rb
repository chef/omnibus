
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
    /libX11\.so\.6/,
    /libXext\.so\.6/,
    /libxcb\.so\.1/,
    /libgmodule-2\.0\.so\.0/,
    /libgobject-2\.0\.so\.0/,
    /libglib-2\.0\.so\.0/,
    /libxshmfence\.so\.1/,
    /libgio-2\.0\.so\.0/,
    /libnss3\.so/,
    /libnssutil3\.so/,
    /libsmime3\.so/,
    /libnspr4\.so/,
    /libatk-1\.0\.so\.0/,
    /libatk-bridge-2\.0\.so\.0/,
    /libdbus-1\.so\.3/,
    /libdrm\.so\.2/,
    /libgtk-3\.so\.0/,
    /libpango-1\.0\.so\.0/,
    /libcairo\.so\.2/,
    /libgdk_pixbuf-2\.0\.so\.0/,
    /libX11\.so\.6/,
    /libXcomposite\.so\.1/,
    /libXdamage\.so\.1/,
    /libXext\.so\.6/,
    /libXfixes\.so\.3/,
    /libXrandr\.so\.2/,
    /libexpat\.so\.1/,
    /libxcb\.so\.1/,
    /libxkbcommon\.so\.0/,
    /libgbm\.so\.1/,
    /libasound\.so\.2/,
    /libatspi\.so\.0/,
    /libcups\.so\.2/,
    /libffi\.so\.6/,
    /libpcre\.so\.3/,
    /libz\.so\.1/,
    /libselinux\.so\.1/,
    /libmount\.so\.1/,
    /libsystemd\.so\.0/,
    /libblkid\.so\.1/,
    /liblzma\.so\.5/,
    /liblz4\.so\.1/,
    /libgcrypt\.so\.20/,
    /libuuid\.so\.1/,
    /libgpg-error\.so\.0/,
    /libpcre\.so\.1/,
    /libplc4\.so/,
    /libplds4\.so/,
    /libcap\.so\.2/,
    /libgcrypt\.so\.11/,
    /libdw\.so\.1/,
    /libattr\.so\.1/,
    /libelf\.so\.1/,
    /libbz2\.so\.1/,
    /libgnutls\.so\.30/,
    /libp11-kit\.so\.0/,
    /libidn2\.so\.0/,
    /libunistring\.so\.2/,
    /libtasn1\.so\.6/,
    /libnettle\.so\.6/,
    /libhogweed\.so\.4/,
    /libgmp\.so\.10/,
    /libpcre2-8\.so\.0/,
    /libXau\.so\.6/,
    /libXdmcp\.so\.6/,
    /libXau\.so\.6/,
    /libXdmcp\.so\.6/,
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

OMNIOS_WHITELIST_LIBS = [
  /libc\.so\.1/,
  /libcrypt\./,
  /libcrypt\.so\.1/,
  /libdl\.so\.1/,
  /libgcc_s\.so\.1/,
  /libgen\.so\.1/,
  /libm\.so\.2/,
  /libmd\.so\.1/,
  /libmp\.so/,
  /libmp\.so\.2/,
  /libnsl\.so\.1/,
  /libpthread\.so\.1/,
  /librt\.so\.1/,
  /libsocket\.so\.1/,
  /libssp\.s/,
  /libssp\.so./,
  /libssp\.so\.0/,
  /libgcc_s\.so\.1/,
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
  /SystemConfiguration/,
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
