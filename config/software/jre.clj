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

(software "jre"
          :source "jre-7u1"
          :steps [
                  {:command "tar" :args [ "xf"
                                         (cond 
                                           (is-machine? "x86_64")
                                           "jre-7u1-linux-x64.tar.gz"
                                           true
                                           "jre-7u1-linux-i586.tar.gz"
                                           )
                                         ]}
                  {:command "cp" :args ["-a" "jre1.7.0_01" "/opt/opscode/embedded/jre"]}
                    ])

