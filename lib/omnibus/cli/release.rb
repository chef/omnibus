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
      option :platform, :required => true, :desc => "build platform of the package", :aliases => :P
      option :platform_version, :required => true, :desc => "build platform version", :aliases => :V
      option :arch, :required => true, :desc => "Build architecture", :aliases => :a
      option :public, :type => :boolean, :default => false, :desc => "Make S3 object publicly readable"
      def package(path)
        o = options
        package_name = File.basename(path)
        # /el/6/i686/chef-10.12.0-1.el6.i686.rpm
        remote_path = File.join(o[:platform], o[:platform_version], o[:arch], package_name)
        remote_uri = "s3://#{o[:bucket]}/#{remote_path}"
        cmd = ["s3cmd", "-c", o[:package_s3_config_file]]
        cmd << "--acl-public" if o[:public]
        cmd.concat ["put", path, remote_uri]
        puts cmd.join(" ")
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

    end
  end
end

