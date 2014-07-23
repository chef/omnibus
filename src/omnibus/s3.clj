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

(ns omnibus.s3
  (:use [omnibus.log]
        [clojure.contrib.logging :only [log]])
  (:import [org.jets3t.service.security AWSCredentials]
           [org.jets3t.service.impl.rest.httpclient RestS3Service]
           [org.jets3t.service.acl AccessControlList]
           [java.io File]
           [org.jets3t.service.model S3Object])
  (:gen-class))

(defn put-in-bucket
  "Place the resulting file in an S3 bucket"
  [filename bucket-name file-key access-key secret-access-key]
  (let [s3 (RestS3Service. (AWSCredentials. access-key secret-access-key))
       s3obj (S3Object. (File. filename))
       s3bucket (. s3 getBucket bucket-name)]
    (. s3obj setAcl AccessControlList/REST_CANNED_PUBLIC_READ)
    (. s3obj setKey file-key)
    (. s3 putObject s3bucket s3obj)))

