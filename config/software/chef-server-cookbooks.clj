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

(software "chef-server-cookbooks" :source "chef-server-cookbooks"
          :steps [
                  {:command "mkdir" :args [ "-p" "/opt/opscode/embedded/cookbooks" ]}
                  {:command "bash" :args [ "-c" "cp -ra * /opt/opscode/embedded/cookbooks/" ] } 
                  {:command "ln" :args [ "-sf" "/opt/opscode/embedded/cookbooks/bin/chef-server-ctl" "/opt/opscode/bin/chef-server-ctl" ] } 
                  ])



