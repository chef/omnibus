#
# Copyright 2012-2014 Chef Software, Inc.
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

require 'fileutils'
require 'aws-sdk'
require 'base64'

module Omnibus
  class S3Cache
    include Logging

    class << self
      #
      # List all software in the cache.
      #
      # @return [Array<Software>]
      #
      def list
        cached = keys
        softwares.select do |software|
          key = key_for(software)
          cached.include?(key)
        end
      end

      #
      # The list of objects in the cache, by their key.
      #
      # @return [Array<String>]
      #
      def keys
        bucket.objects.map(&:key)
      end

      #
      # List all software missing from the cache.
      #
      # @return [Array<Software>]
      #
      def missing
        cached = keys
        softwares.select do |software|
          key = key_for(software)
          !cached.include?(key)
        end
      end

      #
      # Populate the cache with the all the missing software definitions.
      #
      # @return [true]
      #
      def populate
        missing.each do |software|
          without_caching do
            software.fetch
          end

          key     = key_for(software)
          fetcher = software.fetcher

          log.info(log_key) do
            "Caching '#{fetcher.downloaded_file}' to '#{Config.s3_bucket}/#{key}'"
          end

          File.open(fetcher.downloaded_file, 'rb') do |file|
            bucket.put_object({
              key: key,
              body: file,
              content_md5: to_base64_digest(software.fetcher.checksum),
              acl: 'public-read'
            })
          end
        end

        true
      end

      #
      # Fetch all source tarballs onto the local machine.
      #
      # @return [true]
      #
      def fetch_missing
        missing.each do |software|
          without_caching do
            software.fetch
          end
        end
      end

      #
      # @private
      #
      # The key with which to cache the package on S3. This is the name of the
      # package, the version of the package, and its checksum.
      #
      # @example
      #   "zlib-1.2.6-618e944d7c7cd6521551e30b32322f4a"
      #
      # @param [Software] software
      #
      # @return [String]
      #
      def key_for(software)
        unless software.name
          raise InsufficientSpecification.new(:name, software)
        end

        unless software.version
          raise InsufficientSpecification.new(:version, software)
        end

        unless software.fetcher.checksum
          raise InsufficientSpecification.new('source md5 checksum', software)
        end

        "#{software.name}-#{software.version}-#{software.fetcher.checksum}"
      end

      private

      #
      # The client to connect to S3 with.
      #
      # @return [Aws::S3::Resource]
      #
      def client
        @s3 ||= Aws::S3::Resource.new(
          region: 'us-east-1',
          access_key_id:        Config.s3_access_key,
          secret_access_key:    Config.s3_secret_key,
        )
      end

      #
      # The bucket where the objects live.
      #
      # @return [Aws::S3::Bucket]
      #
      def bucket
        @s3_bucket ||= begin
                         bucket = client.bucket(Config.s3_bucket)
                         unless bucket.exists?
                           bucket.create
                         end
                         bucket
                       end
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
        md5_digest = content_md5.unpack('a2'*16).collect {|i| i.hex.chr }.join
        Base64.encode64(md5_digest).strip
      end

      #
      # The list of softwares for all Omnibus projects.
      #
      # @return [Array<Software>]
      #
      def softwares
        Omnibus.projects.inject({}) do |hash, project|
          project.library.each do |software|
            if software.fetcher.is_a?(NetFetcher)
              hash[software.name] = software
            end
          end

          hash
        end.values.sort
      end

      def without_caching(&block)
        original = Config.use_s3_caching
        Config.use_s3_caching(false)

        yield
      ensure
        Config.use_s3_caching(original)
      end
    end
  end
end
