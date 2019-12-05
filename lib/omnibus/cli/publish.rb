#
# Copyright 2013-2014 Chef Software, Inc.
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

module Omnibus
  class Command::Publish < Command::Base
    namespace :publish

    # This option is useful for publish packages that were built for a
    # particular platform/version but tested on other platform/versions.
    #
    # For example, one might build on Ubuntu 10.04 and test/publish on
    # Ubuntu 10.04, 12.04, and 14.04.
    #
    # @example JSON
    #   {
    #     "ubuntu-10.04": [
    #       "ubuntu-10.04",
    #       "ubuntu-12.04",
    #       "ubuntu-14.04"
    #     ]
    #   }
    #
    class_option :platform_mappings,
                 desc: "The optional platform mappings JSON file to publish with",
                 type: :string

    class_option :version_manifest,
                 desc: "Path to the version-manifest.json file to publish with",
                 type: :string

    #
    # Publish to S3.
    #
    #   $ omnibus publish s3 buckethands pkg/chef*
    #
    method_option :acl,
                  type: :string,
                  desc: "The accessibility of the uploaded packages",
                  enum: %w{public private},
                  default: "private"
    method_option :region,
                  type: :string,
                  desc: "The region in which the bucket is located",
                  default: "us-east-1"
    desc "s3 BUCKET PATTERN", "Publish to an S3 bucket"
    def s3(bucket, pattern)
      options[:bucket] = bucket
      publish(S3Publisher, pattern, options)
    end

    #
    # Publish to artifactory.
    #
    #   $ omnibus publish artifactory libs-omnibus-local pkg/chef*
    #
    method_option :build_record,
                  type: :boolean,
                  desc: "Optionally create an Artifactory build record for the published artifacts",
                  default: true
    method_option :properties,
                  type: :hash,
                  desc: "Properites to attach to published artifacts",
                  default: {}
    desc "artifactory REPOSITORY PATTERN", "Publish to an Artifactory instance"
    def artifactory(repository, pattern)
      Omnibus.logger.deprecated("ArtifactoryPublisher") do
        "The `--version-manifest' option has been deprecated. Version manifest data is now part of the `*.metadata.json' file"
      end if options[:version_manifest]

      options[:repository] = repository
      publish(ArtifactoryPublisher, pattern, options)
    end

    private

    #
    # Shortcut method for executing a publisher.
    #
    # @return [void]
    #
    def publish(klass, pattern, options)
      if options[:platform_mappings]
        options[:platform_mappings] = FFI_Yajl::Parser.parse(File.read(File.expand_path(options[:platform_mappings])))
      end

      klass.publish(pattern, options) do |package|
        say("Published '#{package.name}' for #{package.metadata[:platform]}-#{package.metadata[:platform_version]}", :green)
      end
    end
  end
end
