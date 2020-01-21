#
# Copyright 2012-2018 Chef Software, Inc.
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

require "omnibus/s3_helpers"

module Omnibus
  class S3Publisher < Publisher
    include S3Helpers

    def publish(&block)
      log.info(log_key) { "Starting S3 publisher" }

      packages.each do |package|
        # Make sure the package is good to go!
        log.debug(log_key) { "Validating '#{package.name}'" }
        package.validate!

        # Upload the metadata first
        log.debug(log_key) { "Uploading '#{package.metadata.name}'" }

        s3_metadata_object = store_object(
          key_for(package, package.metadata.name),
          FFI_Yajl::Encoder.encode(package.metadata.to_hash, pretty: true),
          nil,
          access_policy
        )

        log.debug(log_key) { "Uploading is completed. Download URL (#{access_policy}): #{s3_metadata_object.public_url}" }

        # Upload the actual package
        log.info(log_key) { "Uploading '#{package.name}'" }

        s3_object = store_object(
          key_for(package, package.name),
          package.content,
          package.metadata[:md5],
          access_policy
        )

        log.info(log_key) { "Uploading is completed. Download URL (#{access_policy}): #{s3_object.public_url}" }

        # If a block was given, "yield" the package to the caller
        yield(package) if block
      end
    end

    private

    def s3_configuration
      config = {
        region: @options[:region],
        bucket_name: @options[:bucket],
      }

      if Config.publish_s3_iam_role_arn
        config[:publish_s3_iam_role_arn] = Config.publish_s3_iam_role_arn
      elsif Config.publish_s3_profile
        config[:profile] = Config.publish_s3_profile
      else
        config[:access_key_id] = Config.publish_s3_access_key
        config[:secret_access_key] = Config.publish_s3_secret_key
      end

      config
    end

    #
    # The unique upload key for this package. The additional "stuff" is
    # postfixed to the end of the path.
    #
    # @example
    #   'el/6/x86_64/chef-11.6.0-1.el6.x86_64.rpm/chef-11.6.0-1.el6.x86_64.rpm'
    #
    # @param [Package] package
    #   the package this key is for
    # @param [Array<String>] stuff
    #   the additional things to append
    #
    # @return [String]
    #
    def key_for(package, *stuff)
      File.join(
        Config.s3_publish_pattern % package.metadata,
        *stuff
      )
    end

    #
    # The access policy that corresponds to the +s3_access+ given in the
    # initializer option. Any access control that is not the strict string
    # +"public"+ is assumed to be private.
    #
    # @return [String]
    #   the access policy
    #
    def access_policy
      if @options[:acl].to_s == "public"
        "public-read"
      else
        "private"
      end
    end
  end
end
