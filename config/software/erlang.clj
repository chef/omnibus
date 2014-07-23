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

(let [args (cond
            (and (is-os? "darwin") (is-machine? "x86_64"))
            ["--prefix=/opt/opscode/embedded"
             "--enable-threads"
             "--enable-smp-support"
             "--enable-kernel-poll"
             "--enable-darwin-64bit"
             "--enable-dynamic-ssl-lib"
             "--enable-m64-build"
             "--without-javac"
             "--with-ssl=/opt/opscode/embedded"
             "--build=i686-apple-darwin10"
             "--disable-hipe"
             "--disable-debug"]
            (is-os? "linux")
            ["--prefix=/opt/opscode/embedded"
             "--enable-threads"
             "--enable-smp-support"
             "--enable-kernel-poll"
             "--enable-dynamic-ssl-lib"
             "--enable-shared-zlib"
             "--enable-hipe"
             "--without-javac"
             "--with-ssl=/opt/opscode/embedded"
             "--disable-debug"])
      env (cond
           (and (is-os? "darwin") (is-machine? "x86_64"))
           { "CFLAGS" "-arch x86_64 -m64 -L/opt/opscode/embedded/lib -I/opt/opscode/embedded/include"
             "LDFLAGS" "-arch x86_64 -R/opt/opscode/embedded/lib -L/opt/opscode/embedded/lib -I/opt/opscode/embedded/include"}
           (is-os? "linux")
           { "CFLAGS" "-L/opt/opscode/embedded/lib -I/opt/opscode/embedded/include"
             "LDFLAGS" "-Wl,-rpath /opt/opscode/embedded/lib -L/opt/opscode/embedded/lib -I/opt/opscode/embedded/include"}
           )
      ]
  (software "erlang" :source "otp_src_R14B02"
            :steps [
 ;                    {:command  "rm" :args ["-f" "/usr/local/bin/erl"]}
 ;                    {:command  "rm" :args ["-f" "/usr/local/bin/erlc"]}
 ;                    {:command  "rm" :args ["-f" "/usr/local/bin/epmd"]}
 ;                    {:command  "rm" :args ["-f" "/usr/local/bin/run_erl"]}
 ;                    {:command  "rm" :args ["-f" "/usr/local/bin/erl"]}
 ;                    {:command  "rm" :args ["-f" "/usr/local/bin/dialyzer"]}
 ;                    {:command  "rm" :args ["-f" "/usr/local/bin/typer"]}
 ;                    {:command  "rm" :args ["-f" "/usr/local/bin/escript"]}
 ;                    {:command  "rm" :args ["-f" "/usr/local/bin/run_test"]}
                    
                    {:command "touch" :args ["lib/wx/SKIP"] }
                    {:command "mkdir" :args ["-p" "lib/hipe/ebin"] } ;; I know, right? [cb]
                    
                    {:env env :command "./configure" :args args}
                    {:env env :command "make" }
                    {:command "make" :args ["install"]}
;                     {:command  "ln" :args ["-sfn" "/opt/opscode/embedded/bin/erl" "/usr/local/bin/erl"]}
;                     {:command  "ln" :args ["-sfn" "/opt/opscode/embedded/bin/erlc" "/usr/local/bin/erlc"]}
;                     {:command  "ln" :args ["-sfn" "/opt/opscode/embedded/bin/epmd" "/usr/local/bin/epmd"]}
;                     {:command  "ln" :args ["-sfn" "/opt/opscode/embedded/bin/run_erl" "/usr/local/bin/run_erl"]}
;                     {:command  "ln" :args ["-sfn" "/opt/opscode/embedded/bin/to_erl" "/usr/local/bin/to_erl"]}
;                     {:command  "ln" :args ["-sfn" "/opt/opscode/embedded/bin/dialyzer" "/usr/local/bin/dialyzer"]}
;                     {:command  "ln" :args ["-sfn" "/opt/opscode/embedded/bin/typer" "/usr/local/bin/typer"]}
;                     {:command  "ln" :args ["-sfn" "/opt/opscode/embedded/bin/escript" "/usr/local/bin/escript"]}
;                     {:command  "ln" :args ["-sfn" "/opt/opscode/embedded/bin/run_test" "/usr/local/bin/run_test"]}
                    ]))

