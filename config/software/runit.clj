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

(software "runit"
          :source "runit-2.1.1"
          :steps [
                  {:command "sed" :args ["-i" "-e" "s:^char *varservice =\"/service/\";$:char *varservice =\"/opt/opscode/service/\";:" "src/sv.c"]}
                  {:command "sed" :args ["-i" "-e" "s:/service:/opt/opscode/service:" "etc/2"]}
                  {:command "sed" :args ["-i" "-e" "s!^PATH=/command:/usr/local/bin:/usr/local/sbin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11R6/bin$!PATH=/opt/opscode/bin:/opt/opscode/embedded/bin:/usr/local/bin:/usr/local/sbin:/bin:/sbin:/usr/bin:/usr/sbin!" "etc/2"]}
                  {:command "sed" :args ["-i" "-e" "s:-static::" "src/Makefile"]}
                  {:command "sh" :args ["-c" "cd src && make"]}
                  {:command "sh" :args ["-c" "cd src && make check"]}
                  {:command "cp" :args ["src/chpst" "/opt/opscode/embedded/bin"]}
                  {:command "cp" :args ["src/runit" "/opt/opscode/embedded/bin"]}
                  {:command "cp" :args ["src/runit-init" "/opt/opscode/embedded/bin"]}
                  {:command "cp" :args ["src/runsv" "/opt/opscode/embedded/bin"]}
                  {:command "cp" :args ["src/runsvchdir" "/opt/opscode/embedded/bin"]}
                  {:command "cp" :args ["src/runsvdir" "/opt/opscode/embedded/bin"]}
                  {:command "cp" :args ["src/sv" "/opt/opscode/embedded/bin"]}
                  {:command "cp" :args ["src/svlogd" "/opt/opscode/embedded/bin"]}
                  {:command "cp" :args ["src/utmpset" "/opt/opscode/embedded/bin"]}
                  {:command "cp" :args ["etc/2" "/opt/opscode/embedded/bin/runsvdir-start"]}
                  {:command "mkdir" :args ["-p" "/opt/opscode/service"]}
                  {:command "mkdir" :args ["-p" "/opt/opscode/sv"]}
                  {:command "mkdir" :args ["-p" "/opt/opscode/init"]}
                 ])

