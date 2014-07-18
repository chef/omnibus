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
require 'uber-s3'

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
        bucket.objects('/').map(&:key)
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

          key = key_for(software)
          content = IO.read(software.downloaded_file)

          log.info(log_key) do
            "Caching '#{software.downloaded_file}' to '#{Config.s3_bucket}/#{key}'"
          end

          client.store(key, content,
            access: :public_read,
            content_md5: software.fetcher.checksum
          )
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
      # @return [UberS3::Client]
      #
      def client
        @client ||= UberS3.new(
          access_key:        Config.s3_access_key,
          secret_access_key: Config.s3_secret_key,
          bucket:            Config.s3_bucket,
          adapter:           :net_http,
        )
      end

      #
      # The bucket where the objects live.
      #
      # @return [UberS3::Bucket]
      #
      def bucket
        @bucket ||= begin
          if client.exists?('/')
            client.bucket
          else
            client.connection.put('/')
          end
        end
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
