;;
;; Author:: Adam Jacob (<adam@opscode.com>)
;; Author:: Christopher Brown (<cb@opscode.com>)
;; Copyright:: Copyright (c) 2010 Opscode, Inc.
;; License:: Apache License, Version 2.0
;;
;; Licensed under the Apache License, Version 2.0 (the "License");
;; you may not use this file except in compliance with the License.
;; You may obtain a copy of the License at
;; 
;;     http://www.apache.org/licenses/LICENSE-2.0
;; 
;; Unless required by applicable law or agreed to in writing, software
;; distributed under the License is distributed on an "AS IS" BASIS,
;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;; See the License for the specific language governing permissions and
;; limitations under the License.
;;

(software "ree" :source "ruby-enterprise-1.8.7-2011.01"
          :steps [
                  {:env {"LD_RUN_PATH" "/opt/opscode/embedded/lib"
                         "LDFLAGS" "-L/opt/opscode/embedded/lib -I/opt/opscode/embedded/include -R/opt/opscode/embedded/lib"
                         "CFLAGS" "-L/opt/opscode/embedded/lib -I/opt/opscode/embedded/include"}
                   :command "./installer"
                   :args ["-a" "/opt/opscode/embedded" "--dont-install-useful-gems" "--no-dev-docs"]} ])

;; These gory bits are going on inside the installer above. Left for future understanding [cb]

;; ["bash" "-c" "cd ./source/distro/google-perftools-1.4 && ./configure --prefix=/opt/opscode/embedded --disable-dependency-tracking && make libtcmalloc_minimal.la"]
;; [ "mkdir" "-p" "/opt/opscode/embedded/lib"]
;; [ "bash" "-c" (str "cp -Rpf " (cond (is-os? "darwin") "./source/distro/google-perftools-1.4/.libs/libtcmalloc_minimal.*" 
;; (is-os? "linux") "./source/distro/google-perftools-1.4/.libs/libtcmalloc_minimal.*") " /opt/opscode/embedded/lib")]
;; ["bash" "-c" "cd ./source && ./configure --prefix=/opt/opscode/embedded --enable-mbari-api CFLAGS='-g -O2' --with-opt-dir=/opt/opscode/embedded"]
;; ["bash" "-c" 
;;  (cond (is-os? "darwin") "cd ./source && make RPATH=/opt/opscode/embedded/lib PRELIBS=\"-Wl,-rpath,/opt/opscode/embedded/lib -L/opt/opscode/embedded/lib -lsystem_allocator -ltcmalloc_minimal\""
;; (is-os? "linux") "cd ./source && make RPATH=/opt/opscode/embedded/lib PRELIBS=\"-Wl,-rpath,/opt/opscode/embedded/lib -L/opt/opscode/embedded/lib -ltcmalloc_minimal\"")]
;; [ "bash" "-c" "cd ./source && env RPATH=/opt/opscode/embedded/lib make install"]])
