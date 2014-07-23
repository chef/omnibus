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

(software "rabbitmq"
          :source "rabbitmq_server-2.2.0"
          :steps [
                  {:command "pwd"}
                  {:command "cp" :args ["-a" "../rabbitmq_server-2.2.0" "/opt/opscode/embedded/lib/erlang/lib"]}
                  {:command "ln" :args ["-sf" "/opt/opscode/embedded/lib/erlang/lib/rabbitmq_server-2.2.0/sbin/rabbitmqctl" "/opt/opscode/embedded/bin/rabbitmqctl"]}
                  {:command "ln" :args ["-sf" "/opt/opscode/embedded/lib/erlang/lib/rabbitmq_server-2.2.0/sbin/rabbitmq-env" "/opt/opscode/embedded/bin/rabbitmq-env"]}
                  {:command "ln" :args ["-sf" "/opt/opscode/embedded/lib/erlang/lib/rabbitmq_server-2.2.0/sbin/rabbitmq-multi" "/opt/opscode/embedded/bin/rabbitmq-multi"]}
                  {:command "ln" :args ["-sf" "/opt/opscode/embedded/lib/erlang/lib/rabbitmq_server-2.2.0/sbin/rabbitmq-server" "/opt/opscode/embedded/bin/rabbitmq-server"]}
                    ])
