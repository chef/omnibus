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
require 'ruby-progressbar'

module Omnibus
  class NetFetcher < Fetcher
    # Use 7-zip to extract 7z/zip for Windows
    WIN_7Z_EXTENSIONS = %w(.7z .zip)

    # tar probably has compression scheme linked in, otherwise for tarballs
    COMPRESSED_TAR_EXTENSIONS = %w(.tar.gz .tgz tar.bz2 .tar.xz .txz .tar.lzma)
    TAR_EXTENSIONS = COMPRESSED_TAR_EXTENSIONS + ['.tar']

    ALL_EXTENSIONS = WIN_7Z_EXTENSIONS + TAR_EXTENSIONS

    # Digest types used for verifying file checksums
    DIGESTS = [:sha512, :sha256, :sha1, :md5]

    #
    # A fetch is required if the downloaded_file (such as a tarball) does not
    # exist on disk, or if the checksum of the downloaded file is different
    # than the given checksum.
    #
    # @return [true, false]
    #
    def fetch_required?
      !(File.exist?(downloaded_file) && digest(downloaded_file, digest_type) == checksum)
    end

    #
    # The version identifier for this remote location. This is computed using
    # the name of the software, the version of the software, and the checksum.
    #
    # @return [String]
    #
    def version_guid
      "#{digest_type}:#{checksum}"
    end

    #
    # Clean the project directory if it exists and actually extract
    # the downloaded file.
    #
    # @return [true, false]
    #   true if the project directory was removed, false otherwise
    #
    def clean
      needs_cleaning = File.exist?(project_dir)
      if needs_cleaning
        log.info(log_key) { "Cleaning project directory `#{project_dir}'" }
        FileUtils.rm_rf(project_dir)
      end
      create_required_directories
      deploy
      needs_cleaning
    end

    #
    # Fetch the given software definition. This method **always** fetches the
    # file, even if it already exists on disk! You should use {#fetch_required?}
    # to guard against this check in your implementation.
    #
    # @return [void]
    #
    def fetch
      log.info(log_key) { "Downloading from `#{download_url}'" }

      create_required_directories
      download
      verify_checksum!
    end

    #
    # The version for this item in the cache. This is the digest of downloaded
    # file and the URL where it was downloaded from.
    #
    # @return [String]
    #
    def version_for_cache
      "download_url:#{source[:url]}|#{digest_type}:#{checksum}"
    end

    #
    # Returned the resolved version for the manifest.  Since this is a
    # remote URL, there is no resolution, the version is what we said
    # it is.
    #
    # @return [String]
    #
    def self.resolve_version(version, source)
      version
    end

    #
    # The path on disk to the downloaded asset. This method requires the
    # presence of a +source_uri+.
    #
    # @return [String]
    #
    def downloaded_file
      filename = File.basename(source[:url], '?*')
      File.join(Config.cache_dir, filename)
    end

    #
    # The checksum as defined by the user in the software definition.
    #
    # @return [String]
    #
    def checksum
      source[digest_type]
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
        "http://#{Config.s3_bucket}.s3.amazonaws.com/#{S3Cache.key_for(self)}"
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

      options = download_headers

      if source[:unsafe]
        log.warn(log_key) { "Permitting unsafe redirects!" }
        options[:allow_unsafe_redirects] = true
      end

      options[:read_timeout] = Omnibus::Config.fetcher_read_timeout
      fetcher_retries ||= Omnibus::Config.fetcher_retries

      progress_bar = ProgressBar.create(
        output: $stdout,
        format: '%e %B %p%% (%r KB/sec)',
        rate_scale: ->(rate) { rate / 1024 },
      )

      reported_total = 0

      options[:content_length_proc] = ->(total) {
        reported_total = total
        progress_bar.total = total
      }
      options[:progress_proc] = ->(step) {
        downloaded_amount = [step, reported_total].min
        progress_bar.progress = downloaded_amount
      }

      file = open(download_url, options)
      FileUtils.cp(file.path, downloaded_file)
      file.close
    rescue SocketError,
           Errno::ECONNREFUSED,
           Errno::ECONNRESET,
           Errno::ENETUNREACH,
           Timeout::Error,
           OpenURI::HTTPError => e
      if fetcher_retries != 0
        log.debug(log_key) { "Retrying failed download (#{fetcher_retries})..." }
        fetcher_retries -= 1
        retry
      else
        log.error(log_key) { "Download failed - #{e.class}!" }
        raise
      end
    end

    #
    # Extract the downloaded file, using the magical logic based off of the
    # ending file extension. In the rare event the file cannot be extracted, it
    # is copied over as a raw file.
    #
    def deploy
      if downloaded_file.end_with?(*ALL_EXTENSIONS)
        log.info(log_key) { "Extracting `#{safe_downloaded_file}' to `#{safe_project_dir}'" }
        extract
      else
        log.info(log_key) { "`#{safe_downloaded_file}' is not an archive - copying to `#{safe_project_dir}'" }

        if File.directory?(downloaded_file)
          # If the file itself was a directory, copy the whole thing over. This
          # seems unlikely, because I do not think it is a possible to download
          # a folder, but better safe than sorry.
          FileUtils.cp_r("#{downloaded_file}/.", project_dir)
        else
          # In the more likely case that we got a "regular" file, we want that
          # file to live **inside** the project directory. project_dir should already
          # exist due to create_required_directories
          FileUtils.cp(downloaded_file, project_dir)
        end
      end
    end

    #
    # Extracts the downloaded archive file into project_dir.
    #
    def extract
      if Ohai['platform'] == 'windows' && downloaded_file.end_with?(*COMPRESSED_TAR_EXTENSIONS)
        # On windows, always use 7z because bsdtar has problems with extracting
        # files that are marked as read-only inside the tar. Unfortunately,
        # this means that we need to perform this in multiple steps as 7z
        # doesn't extract and untar at the same time. The extracted tar is
        # moved out of the project_dir and then extracted once again into
        # project_dir.
        Dir.mktmpdir do |temp_dir|
          log.debug(log_key) { "Temporarily extracting `#{safe_downloaded_file}' to `#{temp_dir}'" }

          shellout!("7z.exe x #{safe_downloaded_file} -o#{windows_safe_path(temp_dir)} -r -y")

          fname = File.basename(downloaded_file, File.extname(downloaded_file))
          fname << ".tar" if downloaded_file.end_with?('tgz', 'txz')
          next_file = windows_safe_path(File.join(temp_dir, fname))

          log.debug(log_key) { "Temporarily extracting `#{next_file}' to `#{safe_project_dir}'" }
          shellout!("7z.exe x #{next_file} -o#{safe_project_dir} -r -y")
        end
      elsif Ohai['platform'] == 'windows'
        shellout!("7z.exe x #{safe_downloaded_file} -o#{safe_project_dir} -r -y")
      elsif downloaded_file.end_with?('.7z')
        shellout!("7z x #{safe_downloaded_file} -o#{safe_project_dir} -r -y")
      elsif downloaded_file.end_with?('.zip')
        shellout!("unzip #{safe_downloaded_file} -d #{safe_project_dir}")
      else
        compression_switch = 'z'        if downloaded_file.end_with?('gz')
        compression_switch = '--lzma -' if downloaded_file.end_with?('lzma')
        compression_switch = 'j'        if downloaded_file.end_with?('bz2')
        compression_switch = 'J'        if downloaded_file.end_with?('xz')
        compression_switch = ''         if downloaded_file.end_with?('tar')

        shellout!("#{tar} #{compression_switch}xf #{safe_downloaded_file} -C#{safe_project_dir}")
      end
    end

    #
    # The digest type defined in the software definition
    #
    # @raise [ChecksumMissing]
    #   if the checksum does not exist
    #
    # @return [Symbol]
    #
    def digest_type
      DIGESTS.each do |digest|
        return digest if source.key? digest
      end
      raise ChecksumMissing.new(self)
    end

    #
    # Verify the downloaded file has the correct checksum.
    #
    # @raise [ChecksumMismatch]
    #   if the checksum does not match
    #
    def verify_checksum!
      log.info(log_key) { 'Verifying checksum' }

      expected = checksum
      actual   = digest(downloaded_file, digest_type)

      if expected != actual
        raise ChecksumMismatch.new(self, expected, actual)
      end
    end

    def safe_project_dir
      windows_safe_path(project_dir)
    end

    def safe_downloaded_file
      windows_safe_path(downloaded_file)
    end

    #
    # The command to use for extracting this piece of software.
    #
    # @return [[String]]
    #
    def extract_command
    end

    #
    # Primitively determine whether we should use gtar or tar to untar a file.
    # If gtar is present, we will use gtar (AIX). Otherwise, we fallback to tar.
    #
    # @return [String]
    #
    def tar
      Omnibus.which('gtar') ? 'gtar' : 'tar'
    end

    #
    # The list of headers to pass to the download.
    #
    # @return [Hash]
    #
    def download_headers
      {}.tap do |h|
        # Alright kids, sit down while grandpa tells you a story. Back when the
        # Internet was just a series of tubes, and you had to "dial in" using
        # this thing called a "modem", ancient astronaunt theorists (computer
        # scientists) invented gzip to compress requests sent over said tubes
        # and make the Internet faster.
        #
        # Fast forward to the year of broadband - ungzipping these files was
        # tedious and hard, so Ruby and other client libraries decided to do it
        # for you:
        #
        #   https://github.com/ruby/ruby/blob/c49ae7/lib/net/http.rb#L1031-L1033
        #
        # Meanwhile, software manufacturers began automatically compressing
        # their software for distribution as a +.tar.gz+, publishing the
        # appropriate checksums accordingly.
        #
        # But consider... If a software manufacturer is publishing the checksum
        # for a gzipped tarball, and the client is automatically ungzipping its
        # responses, then checksums can (read: should) never match! Herein lies
        # the bug that took many hours away from the lives of a once-happy
        # developer.
        #
        # TL;DR - Do not let Ruby ungzip our file
        #
        h['Accept-Encoding'] = 'identity'

        # Set the cookie if one was given
        h['Cookie'] = source[:cookie] if source[:cookie]
      end
    end
  end
end
