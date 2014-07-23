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

(ns omnibus.log
  (:use [clojure.contrib.logging :only [log]])
  (:require [clojure.contrib.string :as str])
  (:gen-class))

(defn log-sh-result
  [status true-log false-log]
  (if (zero? (status :exit))
    (do
      (log :info true-log)
      ;; (log :info (status :exit))
      ;; (log :info (status :out))
      ;; (log :info (status :err))      
      true)
    (do
      (log :error false-log)
      (log :error (str "STDOUT: " (status :out)))
      (log :error (str "STDERR: " (status :err)))
      (System/exit 2))))
