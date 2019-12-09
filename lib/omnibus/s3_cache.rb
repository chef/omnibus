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

require "fileutils"
require "omnibus/s3_helpers"

module Omnibus
  class S3Cache
    include Logging
    extend Digestable

    class << self
      include S3Helpers
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
        client.bucket(Config.s3_bucket).objects.map(&:key)
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

          # Fetcher has already verified the downloaded file in software.fetch.
          # Compute the md5 from scratch because the fetcher may have been
          # specified with a different hashing algorithm.
          md5 = digest(fetcher.downloaded_file, :md5)

          File.open(fetcher.downloaded_file, "rb") do |file|
            store_object(key, file, md5, "public-read")
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

      def get_object(filename, software)
        object = client.bucket(Config.s3_bucket).object(S3Cache.key_for(software))
        object.get(
          response_target: filename,
          bucket: Config.s3_bucket,
          key: key_for(software)
        )
      end

      #
      # @private
      #
      # The key with which to cache the package on S3. This is the name of the
      # package, the version of the package, and its md5 checksum.
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
          raise InsufficientSpecification.new("source md5 checksum", software)
        end

        "#{software.name}-#{software.version}-#{software.fetcher.checksum}"
      end

      def url_for(software)
        client.bucket(Config.s3_bucket).object(S3Cache.key_for(software)).public_url
      end

      private

      def s3_configuration
        config = {
          region: Config.s3_region,
          bucket_name: Config.s3_bucket,
          endpoint: Config.s3_endpoint,
          use_accelerate_endpoint: Config.s3_accelerate,
          force_path_style: Config.s3_force_path_style,
          s3_authenticated_download: Config.s3_authenticated_download,
          retry_limit: Config.fetcher_retries,
        }

        if Config.s3_profile
          config[:profile] = Config.s3_profile
          config[:credentials_file_path] = Config.s3_credentials_file_path
        elsif Config.s3_instance_profile
          if Config.s3_ecs_credentials || ENV['AWS_CONTAINER_CREDENTIALS_RELATIVE_URI']
            config[:ecs_credentials] = true
          else
            config[:instance_profile] = Config.s3_instance_profile
          end
        elsif Config.s3_role
          config[:role] = Config.s3_role
          config[:role_arn] = Config.s3_role_arn
          config[:role_session_name] = Config.s3_role_session_name
          config[:sts_creds_profile] = Config.s3_sts_creds_profile
          config[:sts_creds_ecs_credentials] = Config.s3_sts_creds_ecs_credentials
          config[:sts_creds_instance_profile] = Config.s3_sts_creds_instance_profile
        else
          config[:access_key_id] = Config.s3_access_key
          config[:secret_access_key] = Config.s3_secret_key
        end

        config
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
