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

(software "help2man"
    :source "help2man-1.40.4"
    :steps [
	    {
	     :command "./configure"
	     :args ["--prefix=/opt/opscode/embedded"]
	     }
	    { :command (if (or (is-os? "solaris2") (is-os? "freebsd")) "gmake" "make") }
	    { :command (if (or (is-os? "solaris2") (is-os? "freebsd")) "gmake" "make") :args ["install"]}
	    ])

