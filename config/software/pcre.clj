;;
;; Author:: Adam Jacob (<adam@opscode.com>)
;; Copyright:: Copyright (c) 2011 Opscode, Inc.
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

(software "pcre" :source "pcre-8.20"
          :steps [
                  {:command "./configure"
                   :env {
                         "CFLAGS" "-L/opt/opscode/embedded/lib -I/opt/opscode/embedded/include"
                         }
                   :args ["--prefix=/opt/opscode/embedded" ]}
                  ;; touch aclocal.m4 required to avoid trying to regenerate it
                  {:command "touch" :args ["aclocal.m4"]}
                  {:command "make" :env { "PATH" "/opt/opscode/embedded/bin:/opt/opscode/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin" "LD_RUN_PATH" "/opt/opscode/embedded/lib" }}
                  {:command "make" :args ["install"]}
                  ])

