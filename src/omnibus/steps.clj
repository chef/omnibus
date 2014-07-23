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

(ns omnibus.steps
  (:use [omnibus.log]
        [clojure.contrib.logging :only [log]]
        [clojure.contrib.io :only [make-parents file-str]]
        [clojure.contrib.str-utils :only [str-join]]
        [clojure.java.shell :only [sh with-sh-env with-sh-dir]])
  (:require [clojure.contrib.string :as str])
  (:gen-class))

(defn run-shell
  [step]
  (let [combined-env (merge (hash-map) (System/getenv) (step :env))]
    (with-sh-env combined-env
      (if (step :args)
        (apply sh (cons (step :command) (step :args)))
        (sh (step :command))))))

(defn- execute-step
  "Run a build step"
  [step path]
  (let [step-info (str-join " " (cons (step :command) (step :args)))]
    (log :info (str "Running step: " step-info ))
    (with-sh-dir path
      (log-sh-result (run-shell step)
                     (str "Step command succeeded: " step-info)
                     (str "Step command failed: " step-info)))))

(defn run-steps
  "Run the steps for a given piece of software"
  [build-root soft]
  (log :info (str "Building " (soft :source)))
  (dorun (for [step (soft :steps)] 
    (execute-step step (.getPath (if (= (soft :source) nil)
                                   (file-str build-root)
                                   (if (= (soft :build-subdir) nil)
                                     (file-str build-root "/" (soft :source))
                                     (file-str build-root "/" (soft :source) "/" (soft :build-subdir)))))))))
