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

(let [ env {"RPATH" "/opt/opscode/embedded/lib"
            "CURL_CONFIG" "/opt/opscode/embedded/bin/curl-config"
            "ICU_CONFIG" "/opt/opscode/embedded/bin/icu-config"
            "ERL" "/opt/opscode/embedded/bin/erl"
            "ERLC" "/opt/opscode/embedded/bin/erlc"
            "LD_RUN_PATH" "/opt/opscode/embedded/lib"
            "CFLAGS" "-L/opt/opscode/embedded/lib -I/opt/opscode/embedded/include"
            "PATH" (apply str (interpose ":" ["/opt/opscode/embedded/bin" (System/getenv "PATH")]))} ]
  (software "couchdb" :source "apache-couchdb-1.0.1"
            :steps [
                    {:env env :command "./bootstrap"}
                    {:env env
                     :command "./configure"
                     :args ["--prefix=/opt/opscode/embedded"
                            "--disable-init"
                            "--disable-launchd"
                            "--with-erlang=/opt/opscode/embedded/lib/erlang/usr/include"
                            "--with-js-include=/opt/opscode/embedded/include"
                            "--with-js-lib=/opt/opscode/embedded/lib" ]}
                    {:env env :command "make"}
                    {:env env :command "make" :args ["install"]} ]))

