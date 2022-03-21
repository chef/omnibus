#
# Copyright 2021-present Datadog, Inc.
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
require "omnibus/download_helpers"
require "omnibus/s3_helpers"

module Omnibus
  # Util class to take care of caching license files.
  # This class was written to be similar to the S3Cache class, but is different enough
  # to not be derived from it.
  # In particular, the key_for method needs more parameters, the software
  # list is different, the list of missing cache entries is generated with
  # a slightly different logic (to take standard licenses and local files into
  # account), and the cache population logic is also different (licenses do not
  # have a fetcher).
  class S3LicenseCache
    include Logging
    extend Digestable

    class << self
      include DownloadHelpers
      include S3Helpers

      #
      # The AWS::S3::Bucket object associated with the cache S3 bucket.
      #
      # On ARM Linux and Windows runners, this operation takes up to 40s, so it's better
      # to only do it once and then keep the object for all future operations.
      #
      # @return[AWS::S3::Bucket]
      #
      def bucket
        if @bucket.nil?
          @bucket = client.bucket(Config.s3_bucket)
        end
        @bucket
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
      # List all software licenses missing from the cache.
      # Discards local files (which do not need to be cached), and
      # takes into account standard licenses.
      #
      # @return [Array<[Software, String]>]
      #
      def missing
        cached = keys
        missing_license_files = []

        softwares.each do |software|
          license_files = software.license_files
          # If the license is a standard license, use the STANDARD_LICENSES URL associated with it
          if software.license_files.empty? && Licensing::STANDARD_LICENSES.keys.include?(software.license)
            license_files = [Licensing::STANDARD_LICENSES[software.license]]
          end

          license_files.each do |license_file|
            # No need to cache local files
            next if local?(license_file)

            key = key_for(software, license_file)
            missing_license_files << [software, license_file] if !cached.include?(key)
          end
        end

        missing_license_files
      end

      #
      # Populate the cache with the all the missing licenses.
      #
      # @return [true]
      #
      def populate
        # Create local licenses cache directory
        FileUtils.mkdir_p(Config.license_cache_dir)

        missing.each do |software, license_file|
          # Fetch the license file
          license_basename = File.basename(license_file)
          downloaded_file = File.join(Config.license_cache_dir, "#{software.name}-#{license_basename}")
          download_file!(license_file, downloaded_file, enable_progress_bar: false)

          # Upload the license file
          key = key_for(software, license_file)

          log.info(log_key) do
            "Caching '#{downloaded_file}' to '#{Config.s3_bucket}/#{key}'"
          end

          # The AWS client needs the md5 of the file that is uploaded
          md5 = digest(downloaded_file, :md5)

          File.open(downloaded_file, "rb") do |file|
            store_object(key, file, md5, "public-read")
          end
        end

        true
      end

      #
      # Retrieves the a given license file for a software from S3
      # and stores it in the given location.
      #
      # @param [Software] software
      # @param [String] license_file
      # @param [String] destination
      #
      def get_object(software, license_file, destination)
        object = bucket.object(key_for(software, license_file))

        object.get(
          response_target: destination
        )
      end

      #
      # @private
      #
      # The key with which to cache the license on S3. This is the name of the
      # package, the version of the package, a shasum of the software definition
      # and the license file name.
      #
      # @example
      #   "licenses/zlib-1.2.6-eb4547923e5311e8cca1fb538f1262b12c3b42ec488a9cd1bdc7e9cb630b4d96/LICENSE"
      #
      # @param [Software] software
      # @param [String] license_file
      #
      # @return [String]
      #
      def key_for(software, license_file)
        unless software.name
          raise InsufficientSpecification.new(:name, software)
        end

        unless software.version
          raise InsufficientSpecification.new(:version, software)
        end

        unless software.hash
          raise InsufficientSpecification.new(:hash, software)
        end

        # We add Software#shasum in the cache key. It's an accurate way
        # to know if a software definition changed, as it takes into account the
        # resolved version (ie. the git commit hash if the source is a git repository,
        # the hashsum of the downloaded file if the source is a remote file), the project,
        # and all build commands run in the software definition.
        "licenses/#{software.name}-#{software.version}-#{software.shasum}/#{File.basename(license_file)}"
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
      # Contrary to S3Cache, we want all software definitions,
      # not only the ones that use the NetFetcher, as software
      # definitions using other fetchers (PathFetcher, GitFetcher, etc.)
      # could still use a remote license file.
      #
      # @return [Array<Software>]
      #
      def softwares
        Omnibus.projects.inject({}) do |hash, project|
          project.library.each do |software|
            hash[software.name] = software
          end
          hash
        end.values.sort
      end

      #
      # Returns if the given path to a license is local or a remote url.
      #
      # @return [Boolean]
      #
      def local?(license)
        u = URI(license)
        return u.scheme.nil?
      end
    end
  end
end
