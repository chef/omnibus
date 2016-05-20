#
# Copyright 2015 Chef Software, Inc.
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

require "aws-sdk"
require "base64"

module Omnibus
  module S3Helpers
    def self.included(base)
      base.send(:include, InstanceMethods)
    end

    module InstanceMethods
      private

      #
      # Returns the configuration for S3. You must provide keys
      # :region,
      #
      # @example
      #   {
      #     region:               'us-east-1',
      #     access_key_id:        Config.s3_access_key,
      #     secret_access_key:    Config.s3_secret_key,
      #     bucket_name:          Config.s3_bucket
      #   }
      #
      # @return [Hash<String, String>]
      #
      def s3_configuration
        raise "You must override s3_configuration"
      end

      #
      # The client to connect to S3 with.
      #
      # @return [Aws::S3::Resource]
      #
      def client
        @s3_client ||= Aws::S3::Resource.new(
          region:            s3_configuration[:region],
          access_key_id:     s3_configuration[:access_key_id],
          secret_access_key: s3_configuration[:secret_access_key]
        )
      end

      #
      # The bucket where the objects live.
      #
      # @return [Aws::S3::Bucket]
      #
      def bucket
        @s3_bucket ||= begin
                         bucket = client.bucket(s3_configuration[:bucket_name])
                         unless bucket.exists?
                           bucket_config = if s3_configuration[:region] == "us-east-1"
                                             nil
                                           else
                                             {
                                               location_constraint: s3_configuration[:region],
                                             }
                                           end
                           bucket.create(create_bucket_configuration: bucket_config)
                         end
                         bucket
                       end
      end

      #
      # Store an object at the specified key
      #
      # @param [String] key
      # @param [File, String] content
      # @param [String] content_md5
      # @param [String] acl
      #
      # @return [true]
      #
      def store_object(key, content, content_md5, acl)
        bucket.put_object({
          key: key,
          body: content,
          content_md5: to_base64_digest(content_md5),
          acl: acl,
        })
        true
      end

      #
      # Convert a hex digest into a base64 hex digest
      #
      # For example:
      # to_base64_digest('c3b5247592ce694f7097873aa07d66fe') => 'w7UkdZLOaU9wl4c6oH1m/g=='
      #
      # @param [String] content_md5
      #
      # @return [String]
      #
      def to_base64_digest(content_md5)
        if content_md5
          md5_digest = content_md5.unpack("a2" * 16).collect { |i| i.hex.chr }.join
          Base64.encode64(md5_digest).strip
        end
      end
    end
  end
end
