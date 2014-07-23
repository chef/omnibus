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

(let [initial-steps
      [{:env { "LD_RUN_PATH" "/opt/opscode/embedded/lib" } :command "make" :args ["BUILD_OPT=1" "XCFLAGS=-L/opt/opscode/embedded/lib -I/opt/opscode/embedded/include" "-f" "Makefile.ref"]}
       {:env { "LD_RUN_PATH" "/opt/opscode/embedded/lib" } :command "make" :args ["BUILD_OPT=1" "JS_DIST=/opt/opscode/embedded" "-f" "Makefile.ref" "export"]}]
      steps
      (cond
       (and (is-os? "linux") (is-machine? "x86_64"))
       (concat
        initial-steps
        [{:command "mv" :args ["/opt/opscode/embedded/lib64/libjs.a" "/opt/opscode/embedded/lib"]}
         {:command "mv" :args ["/opt/opscode/embedded/lib64/libjs.so" "/opt/opscode/embedded/lib"]}
         {:command "rm" :args ["-rf" "/opt/opscode/embedded/lib64"]}])
       true
       initial-steps)]
  (software "spidermonkey"
            :source "js"
            :build-subdir "src"
            :steps steps))
