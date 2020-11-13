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
  class PathFetcher < Fetcher
    #
    # Fetch if the local directory checksum is different than the path directory
    # checksum.
    #
    # @return [true, false]
    #
    def fetch_required?
      target_shasum != destination_shasum
    end

    #
    # The version identifier for this path. This is computed using the path
    # on disk to the source and the recursive shasum of that path on disk.
    #
    # @return [String]
    #
    def version_guid
      "path:#{source_path}"
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
      log.info(log_key) { "Copying from `#{source_path}'" }

      create_required_directories
      FileSyncer.sync(source_path, project_dir, source_options)
      # Reset target shasum on every fetch
      @target_shasum = nil
      target_shasum
    end

    #
    # The version for this item in the cache. The is the shasum of the directory
    # on disk.
    #
    # This method is called *before* clean but *after* fetch. Since fetch
    # automatically cleans, target vs. destination sha doesn't matter. Change this
    # if that assumption changes.
    #
    # @return [String]
    #
    def version_for_cache
      "path:#{source_path}|shasum:#{destination_shasum}"
    end

    #
    # @return [String, nil]
    #
    def self.resolve_version(version, source)
      version
    end

    private

    #
    # The path on disk to pull the files from.
    #
    # @return [String]
    #
    def source_path
      source[:path]
    end

    #
    # Options to pass to the underlying FileSyncer
    #
    # @return [Hash]
    #
    def source_options
      if source[:options] && source[:options].is_a?(Hash)
        source[:options]
      else
        {}
      end
    end

    #
    # The shasum of the directory **inside** the project.
    #
    # @return [String]
    #
    def target_shasum
      @target_shasum ||= digest_directory(project_dir, :sha256, source_options)
    end

    #
    # The shasum of the directory **outside** of the project.
    #
    # @return [String]
    #
    def destination_shasum
      @destination_shasum ||= digest_directory(source_path, :sha256, source_options)
    end
  end
end
