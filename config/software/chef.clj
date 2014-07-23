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

(software "chef" :source "chef"
          :steps [
                  {:command "/opt/opscode/embedded/bin/gem"
                   :args ["install" "chef" "--version" "10.12.0" "-n" "/opt/opscode/bin"
                          "--no-rdoc" "--no-ri"
                          "--" "--with-xml2-include=/opt/opscode/embedded/include/libxml2"
                          "--with-xml2-lib=/opt/opscode/embedded/lib"]}
                  {:command "/opt/opscode/embedded/bin/gem"
                   :args ["install" "highline" "net-ssh-multi" "knife-ec2" "knife-rackspace" "-n" "/opt/opscode/bin"
                          "--no-rdoc" "--no-ri"
                          "--" "--with-xml2-include=/opt/opscode/embedded/include/libxml2"
                          "--with-xml2-lib=/opt/opscode/embedded/lib"]}
                  {:command "cp" :args ["setup.sh" "/opt/opscode"]}
                  {:command "chmod" :args ["755" "/opt/opscode/setup.sh"]}
                  {:command "rm" :args ["-rf" "/opt/opscode/embedded/docs"]}
                  {:command "rm" :args ["-rf" "/opt/opscode/embedded/share/man"]}
                  {:command "rm" :args ["-rf" "/opt/opscode/embedded/share/doc"]}
                  {:command "rm" :args ["-rf" "/opt/opscode/embedded/share/gtk-doc"]}
                  {:command "rm" :args ["-rf" "/opt/opscode/embedded/ssl/man"]}
                  {:command "rm" :args ["-rf" "/opt/opscode/embedded/man"]}
                  {:command "rm" :args ["-rf" "/opt/opscode/embedded/info"]}])

