#
# Copyright:: Copyright (c) 2013 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'omnibus/cli/base'
require 'omnibus/cli/application'
require 'json'

module Omnibus
  module CLI


    class Release < Base

      # NOTE: This only removes the options from help output. They still shadow
      # the options here, so you can't define -c or -p.
      class_options.clear

      namespace :release

      def initialize(args, options, config)
        super(args, options, config)
      end

      desc "package PATH", "Upload a single package to S3"
      option :bucket, :required => true, :desc => "S3 bucket to upload to", :aliases => :b
      option :package_s3_config_file, :required => true, :desc => "Path to s3cmd config file for packages bucket", :aliases => :C
      option :public, :type => :boolean, :default => false, :desc => "Make S3 object publicly readable"
      def package(path)
        raise "TODO"
      end

      desc "omnitruck-package", "Upload all packages from a Jenkins Matrix job to S3, with a separate metadata bucket"
      option :project, :required => true, :desc => "Project to release", :aliases => :p
      option :version, :desc => "Project version. Defaults to git-based version", :aliases => :v
      option :bucket, :required => true, :desc => "S3 bucket to upload to", :aliases => :b
      option :package_s3_config_file, :required => true, :desc => "Path to s3cmd config file for packages bucket", :aliases => :c
      option :metadata_bucket, :required => true, :desc => "Name of S3 bucket where package metadata is stored", :aliases => :M
      option :metadata_s3_config_file, :required => true, :desc => "Path to s3cmd config file for metadata bucket", :aliases => :m
      option :ignore_missing_packages, :type => :boolean, :default => false
      def jenkins_matrix
      end

      def read_package_metadata(metadata_path)
        JSON.parse(IO.read(metadata_path))
      end

    end
  end
end

