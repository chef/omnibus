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

(let 
  [env (if (= 0 (get (clojure.java.shell/sh "test" "-f" "/usr/bin/gcc44") :exit)) 
         { "CC" "gcc44" "CXX" "g++44" } 
         { })]

(software "gecode"
          :source "gecode-3.7.1"
          :steps [
                  {:command "./configure" :env env :args [ "--prefix=/opt/opscode/embedded" "--disable-doc-dot" "--disable-doc-search" "--disable-doc-tagfile" "--disable-doc-chm" "--disable-doc-docset" "--disable-qt" "--disable-examples" ]}
                  {:env {"LD_RUN_PATH" "/opt/opscode/embedded/lib"} :command "make"}
                  {:command "make" :args [ "install" ]}
                 ]))


