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
require 'open-uri'

module Omnibus
  class NetFetcher < Fetcher
    # Use 7-zip to extract 7z/zip for Windows
    WIN_7Z_EXTENSIONS = %w(.7z .zip)

    # tar probably has compression scheme linked in, otherwise for tarballs
    TAR_EXTENSIONS = %w(.tar .tar.gz .tgz .bz2 .tar.xz .txz)

    #
    # A fetch is required if the downloaded_file (such as a tarball) does not
    # exist on disk, or if the checksum of the downloaded file is different
    # than the given checksum.
    #
    # @return [true, false]
    #
    def fetch_required?
      !(File.exist?(downloaded_file) && digest(downloaded_file, :md5) == checksum)
    end

    #
    # The version identifier for this remote location. This is computed using
    # the name of the software, the version of the software, and the checksum.
    #
    # @return [String]
    #
    def version_guid
      "md5:#{checksum}"
    end

    #
    # Clean the project directory by removing the contents from disk.
    #
    # @return [true, false]
    #   true if the project directory was removed, false otherwise
    #
    def clean
      if File.exist?(project_dir)
        log.info(log_key) { "Cleaning project directory `#{project_dir}'" }
        FileUtils.rm_rf(project_dir)
        extract
        true
      else
        extract
        false
      end
    end

    #
    # Fetch the given software definition. This method **always** fetches the
    # file, even if it already exists on disk! You should use {fetch_required?}
    # to guard against this check in your implementation.
    #
    # @return [void]
    #
    def fetch
      log.info(log_key) { "Downloading from `#{download_url}'" }

      create_required_directories
      download
      verify_checksum!
      extract
    end

    #
    # The version for this item in the cache. The is the md5 of downloaded file
    # and the URL where it was downloaded from.
    #
    # @return [String]
    #
    def version_for_cache
      "download_url:#{source[:url]}|md5:#{source[:md5]}"
    end

    #
    # The path on disk to the downloaded asset. This method requires the
    # presence of a +source_uri+.
    #
    # @return [String]
    #
    def downloaded_file
      filename = source[:url].split('/')[-1]
      File.join(Config.cache_dir, filename)
    end

    #
    # The checksum (+md5+) as defined by the user in the software definition.
    #
    # @return [String]
    #
    def checksum
      source[:md5]
    end

    private

    #
    # The URL from which to download the software - this comes from the
    # software's +source :url+ value.
    #
    # If S3 caching is enabled, this is the download URL for the software from
    # the S3 bucket as defined in the {Config}.
    #
    # @return [String]
    #
    def download_url
      if Config.use_s3_caching
        "http://#{Config.s3_bucket}.s3.amazonaws.com/#{S3Cache.key_for(software)}"
      else
        source[:url]
      end
    end

    #
    # Download the given file using Ruby's +OpenURI+ implementation. This method
    # may emit warnings as defined in software definitions using the +:warning+
    # key.
    #
    # @return [void]
    #
    def download
      log.warn(log_key) { source[:warning] } if source.key?(:warning)

      file = open(download_url, download_headers)
      FileUtils.cp(file.path, downloaded_file)
      file.close
    rescue SocketError,
           Errno::ECONNREFUSED,
           Errno::ECONNRESET,
           Errno::ENETUNREACH,
           OpenURI::HTTPError => e
      log.error(log_key) { "Download failed - #{e.class}!" }
      raise
    end

    #
    # Extract the downloaded file, using the magical logic based off of the
    # ending file extension. In the rare event the file cannot be extracted, it
    # is copied over as a raw file.
    #
    def extract
      if command = extract_command
        log.info(log_key) { "Extracting `#{downloaded_file}' to `#{Config.source_dir}'" }
        shellout!(extract_command)
      else
        log.info(log_key) { "`#{downloaded_file}' is not an archive - copying to `#{project_dir}'" }

        if File.directory?(project_dir)
          # If the file itself was a directory, copy the whole thing over. This
          # seems unlikely, because I do not think it is a possible to download
          # a folder, but better safe than sorry.
          FileUtils.cp_r(downloaded_file, project_dir)
        else
          # In the more likely case that we got a "regular" file, we want that
          # file to live **inside** the project directory.
          FileUtils.mkdir_p(project_dir)
          FileUtils.cp(downloaded_file, "#{project_dir}/")
        end
      end
    end

    #
    # Verify the downloaded file has the correct checksum.#
    #
    # @raise [ChecksumMismatch]
    #   if the checksum does not match
    #
    def verify_checksum!
      log.info(log_key) { 'Verifying checksum' }

      expected = checksum
      actual   = digest(downloaded_file, :md5)

      if expected != actual
        raise ChecksumMismatch.new(software, expected, actual)
      end
    end

    #
    # The command to use for extracting this piece of software.
    #
    # @return [String, nil]
    #
    def extract_command
      if Ohai['platform'] == 'windows' && downloaded_file.end_with?(*WIN_7Z_EXTENSIONS)
        "7z.exe x #{windows_safe_path(downloaded_file)} -o#{Config.source_dir} -r -y"
      elsif Ohai['platform'] != 'windows' && downloaded_file.end_with?('.7z')
        "7z x #{windows_safe_path(downloaded_file)} -o#{Config.source_dir} -r -y"
      elsif Ohai['platform'] != 'windows' && downloaded_file.end_with?('.zip')
        "unzip #{windows_safe_path(downloaded_file)} -d #{Config.source_dir}"
      elsif downloaded_file.end_with?(*TAR_EXTENSIONS)
        compression_switch = 'z' if downloaded_file.end_with?('gz')
        compression_switch = 'j' if downloaded_file.end_with?('bz2')
        compression_switch = 'J' if downloaded_file.end_with?('xz')
        compression_switch = ''  if downloaded_file.end_with?('tar')
        "tar #{compression_switch}xf #{windows_safe_path(downloaded_file)} -C#{Config.source_dir}"
      end
    end

    #
    #
    #
    def download_headers
      {}.tap do |h|
        h['Cookie'] = source[:cookie] if source[:cookie]
      end
    end
  end
end
