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

require "fileutils" unless defined?(FileUtils)

module Omnibus
  class FileFetcher < Fetcher
    #
    # Fetch if the local file checksum is different than the path file
    # checksum.
    #
    # @return [true, false]
    #
    def fetch_required?
      target_shasum != destination_shasum
    end

    #
    # The version identifier for this file. This is computed using the file
    # on disk to the source and the shasum of that file on disk.
    #
    # @return [String]
    #
    def version_guid
      "file:#{source_file}"
    end

    #
    # Clean the given path by removing the project directory.
    #
    # @return [true, false]
    #   true if the directory was cleaned, false otherwise.
    #   Since we do not currently use the cache to sync files and
    #   always fetch from source, there is no need to clean anything.
    #   The fetch step (which needs to be called before clean) would
    #   have already removed anything extraneous.
    #
    def clean
      true
    end

    #
    # Fetch any new files by copying them to the +project_dir+.
    #
    # @return [void]
    #
    def fetch
      log.info(log_key) { "Copying from `#{source_file}'" }

      create_required_directories
      FileUtils.cp(source_file, target_file)
      # Reset target shasum on every fetch
      @target_shasum = nil
      target_shasum
    end

    #
    # The version for this item in the cache. The is the shasum of the file
    # on disk.
    #
    # This method is called *before* clean but *after* fetch. Since fetch
    # automatically cleans, target vs. destination sha doesn't matter. Change this
    # if that assumption changes.
    #
    # @return [String]
    #
    def version_for_cache
      "file:#{source_file}|shasum:#{destination_shasum}"
    end

    #
    # @return [String, nil]
    #
    def self.resolve_version(version, source)
      version
    end

    private

    #
    # The path on disk to pull the file from.
    #
    # @return [String]
    #
    def source_file
      source[:file]
    end

    #
    # The path on disk where the file is stored.
    #
    # @return [String]
    #
    def target_file
      File.join(project_dir, File.basename(source_file))
    end

    #
    # The shasum of the file **inside** the project.
    #
    # @return [String, nil]
    #
    def target_shasum
      @target_shasum ||= digest(target_file, :sha256)
    rescue Errno::ENOENT
      @target_shasum = nil
    end

    #
    # The shasum of the file **outside** of the project.
    #
    # @return [String]
    #
    def destination_shasum
      @destination_shasum ||= digest(source_file, :sha256)
    end
  end
end
