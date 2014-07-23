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

(software "curl" :source "curl-7.21.2"
          :steps [
                  {:command "./configure"
                   :args ["--prefix=/opt/opscode/embedded"
                          "--disable-debug"
                          "--enable-optimize"
                          "--disable-ldap"
                          "--disable-ldaps"
                          "--disable-rtsp"
                          "--enable-proxy"
                          "--disable-dependency-tracking"
                          "--enable-ipv6"
                          "--without-libidn"
                          "--with-ssl=/opt/opscode/embedded"
                          "--with-zlib=/opt/opscode/embedded"]}
                  {:command "make" :env { "LD_RUN_PATH" "/opt/opscode/embedded/lib" }}
                  {:command "make" :args ["install"]}
                 ; {:command "ln"
                 ;  :args ["-sfn"
                 ;         "/opt/opscode/embedded/bin/curl-config"
                 ;         "/usr/local/bin/curl-config"]}
                  ])


