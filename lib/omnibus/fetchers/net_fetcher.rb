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
require "omnibus/download_helpers"

module Omnibus
  class NetFetcher < Fetcher
    include DownloadHelpers

    # Use 7-zip to extract 7z/zip for Windows
    WIN_7Z_EXTENSIONS = %w{.7z .zip}

    # tar probably has compression scheme linked in, otherwise for tarballs
    COMPRESSED_TAR_EXTENSIONS = %w{.tar.gz .tgz tar.bz2 .tar.xz .txz .tar.lzma}
    TAR_EXTENSIONS = COMPRESSED_TAR_EXTENSIONS + [".tar"]

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
      create_required_directories
      download
      verify_checksum!
    end

    #
    # The version for this item in the cache. This is the digest of downloaded
    # file and the URL where it was downloaded from.
    #
    # This method is called *before* clean but *after* fetch. Do not ever
    # use the contents of the project_dir here.
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
      basename = File.basename(source[:url], "?*")
      File.join(Config.cache_dir, "#{self.name}-#{basename}")
    end

    #
    # The target filename to copy the downloaded file as.
    # Defaults to {#downloaded_file} unless overriden on the source.
    #
    # @return [String]
    #
    def target_filename
      source[:target_filename] || downloaded_file
    end

    #
    # Tells if the sources should be shipped
    #
    # @return [Boolean]
    #
    def ship_source?
      source[:ship_source]
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
        S3Cache.url_for(self)
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

      options = {}

      if source[:unsafe]
        log.warn(log_key) { "Permitting unsafe redirects!" }
        options[:allow_unsafe_redirects] = true
      end

      # Set the cookie if one was given
      options["Cookie"] = source[:cookie] if source[:cookie]

      # The s3 bucket isn't public, force downloading using the sdk
      if Config.use_s3_caching && Config.s3_authenticated_download
        get_from_s3
      else
        log.info(log_key) { "Fetching file from `#{download_url}'" }
        download_file!(download_url, downloaded_file, options)
      end
    end

    #
    # Download the file directly from s3 using get_object
    #
    def get_from_s3
      log.info(log_key) { "Fetching file from S3 object `#{S3Cache.key_for(self)}' in bucket `#{Config.s3_bucket}'" }
      begin
        S3Cache.get_object(downloaded_file, self)
      rescue Aws::S3::Errors::NoSuchKey => e
        log.error(log_key) {
          "Download failed - #{e.class}!"
        }
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
          log.info(log_key) { "`#{safe_downloaded_file}' is a regular file - naming copy `#{target_filename}'" }
          FileUtils.cp(downloaded_file, File.join(project_dir, target_filename))
        end
      end
      if ship_source?
        FileUtils.mkdir_p("#{sources_dir}/#{name}")
        log.info(log_key) { "Moving the sources #{sources_dir}/#{name}/#{downloaded_file.split("/")[-1]}" }
        if File.directory?(downloaded_file)
          FileUtils.cp_r("#{downloaded_file}/.", "#{sources_dir}/#{name}")
        else
          FileUtils.cp(downloaded_file, "#{sources_dir}/#{name}")
        end
      end
    end

    #
    # Extracts the downloaded archive file into project_dir.
    #
    # On windows, this is a fuster cluck and we allow users to specify the
    # preferred extractor to be used. The default is to use tar. User overrides
    # can be set in source[:extract] as:
    #   :tar - use tar.exe and fail on errors (default strategy).
    #   :seven_zip - use 7zip for all tar/compressed tar files on windows.
    #   :lax_tar - use tar.exe on windows but ignore errors.
    #
    # Both 7z and bsdtar have issues on windows.
    #
    # 7z cannot extract and untar at the same time. You need to extract to a
    # temporary location and then extract again into project_dir.
    #
    # 7z also doesn't handle symlinks well. A symlink to a non-existent
    # location simply results in a text file with the target path written in
    # it. It does this without throwing any errors.
    #
    # bsdtar will exit(1) if it is encounters symlinks on windows. So we can't
    # use shellout! directly.
    #
    # bsdtar will also exit(1) and fail to overwrite files at the destination
    # during extraction if a file already exists at the destination and is
    # marked read-only. This used to be a problem when we weren't properly
    # cleaning an existing project_dir. It should be less of a problem now...
    # but who knows.
    #
    def extract
      # Only used by tar
      compression_switch = ""
      compression_switch = "z"        if downloaded_file.end_with?("gz")
      compression_switch = "--lzma -" if downloaded_file.end_with?("lzma")
      compression_switch = "j"        if downloaded_file.end_with?("bz2")
      compression_switch = "J"        if downloaded_file.end_with?("xz")

      if Ohai["platform"] == "windows"
        if downloaded_file.end_with?(*TAR_EXTENSIONS) && source[:extract] != :seven_zip
          returns = [0]
          returns << 1 if source[:extract] == :lax_tar

          shellout!("tar #{compression_switch}xf #{safe_downloaded_file} -C#{safe_project_dir} --force-local || \
                     tar #{compression_switch}xf #{safe_downloaded_file} -C#{safe_project_dir} ", returns: returns)
        elsif downloaded_file.end_with?(*COMPRESSED_TAR_EXTENSIONS)
          Dir.mktmpdir do |temp_dir|
            log.debug(log_key) { "Temporarily extracting `#{safe_downloaded_file}' to `#{temp_dir}'" }

            shellout!("7z.exe x #{safe_downloaded_file} -o#{windows_safe_path(temp_dir)} -r -y")

            fname = File.basename(downloaded_file, File.extname(downloaded_file))
            fname << ".tar" if downloaded_file.end_with?("tgz", "txz")
            next_file = windows_safe_path(File.join(temp_dir, fname))
            next_file = Dir.glob(File.join(temp_dir, '**', '*.tar'))[0] unless File.file?(next_file)

            log.debug(log_key) { "Temporarily extracting `#{next_file}' to `#{safe_project_dir}'" }
            shellout!("7z.exe x #{next_file} -o#{safe_project_dir} -r -y")
          end
        else
          shellout!("7z.exe x #{safe_downloaded_file} -o#{safe_project_dir} -r -y")
        end
      elsif downloaded_file.end_with?(".7z")
        shellout!("7z x #{safe_downloaded_file} -o#{safe_project_dir} -r -y")
      elsif downloaded_file.end_with?(".zip")
        shellout!("unzip #{safe_downloaded_file} -d #{safe_project_dir}")
      else
        shellout!("#{tar} #{compression_switch}xfo #{safe_downloaded_file} -C#{safe_project_dir}")
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
      log.info(log_key) { "Verifying checksum of `#{downloaded_file}'" }

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
      Omnibus.which("gtar") ? "gtar" : "tar"
    end
  end
end
