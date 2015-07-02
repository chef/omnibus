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

    # These options are useful for publish packages that were built for a
    # paticluar platform/version and tested on another platform/version.
    #
    # For example, one might build on Ubuntu 10.04 and test/publish on
    # Ubuntu 11.04, 12.04 and Debian 7.
    #
    # If these options are used with the glob pattern support all packages
    # will be published to the same platform/version.
    class_option :platform,
      desc: 'The platform to publish for',
      type: :string
    class_option :platform_version,
      desc: 'The platform version to publish for',
      type: :string

    class_option :version_manifest,
      desc: 'Path to the version-manifest.json file to publish with',
      type: :string

    #
    # Publish to S3.
    #
    #   $ omnibus publish s3 buckethands pkg/chef*
    #
    method_option :acl,
      type: :string,
      desc: 'The accessibility of the uploaded packages',
      enum: %w(public private),
      default: 'private'
    desc 's3 BUCKET PATTERN', 'Publish to an S3 bucket'
    def s3(bucket, pattern)
      options[:bucket] = bucket
      publish(S3Publisher, pattern, options)
    end

    #
    # Publish to artifactory.
    #
    #   $ omnibus publish artifactory libs-omnibus-local pkg/chef*
    #
    desc 'artifactory REPOSITORY PATTERN', 'Publish to an Artifactory instance'
    def artifactory(repository, pattern)
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
      klass.publish(pattern, options) do |package|
        say("Uploaded '#{package.name}'", :green)
      end
    end
  end
end
