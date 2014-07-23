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

(ns omnibus.ohai
  (:use [omnibus.log]
        [clojure.contrib.json]
        [clojure.contrib.logging :only [log]]
        [clojure.contrib.io :only [make-parents file-str]]
        [clojure.java.shell :only [sh]])
  (:require [clojure.contrib.string :as str])
  (:gen-class))

(defn ohai
  "Use Ohai to get our Operating System and Machine Architecture"
  []
  (let [ohai-data (read-json ((sh "ohai") :out))]
    {:os (get ohai-data :os), 
     :machine (get-in ohai-data [:kernel :machine]),
     :platform (let [ohai-platform (get ohai-data :platform)] 
                 (if (or (= ohai-platform "scientific") (= ohai-platform "redhat") (= ohai-platform "centos")) "el" ohai-platform)),
     :platform_version (get ohai-data :platform_version)}))

(def ohai (memoize ohai))

(defn os-and-machine
  [& ohai-keys]
  (get-in (ohai) ohai-keys))

(defn is-platform?
  "Returns true if the current platform matches the argument"
  [to-check]
  (= (os-and-machine :platform) to-check))

(defn is-os?
  "Returns true if the current OS matches the argument"
  [to-check]
  (= (os-and-machine :os) to-check))

(defn is-machine?
  "Returns true if the current machine matches the argument"
  [to-check]
  (= (os-and-machine :machine) to-check))

