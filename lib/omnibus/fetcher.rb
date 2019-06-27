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

module Omnibus
  class Fetcher
    include Digestable
    include Logging
    include Util
    extend Util

    #
    # The name of the software this fetcher shall fetch
    #
    # @return [String]
    #
    attr_reader :name

    #
    # The source for this fetcher.
    #
    # @return [Hash]
    #
    attr_reader :source

    #
    # The exact upstream version that a fetcher should fetch.
    #
    # @return [String]
    #
    # For sources that allow aliases (branch name, tags, etc). Users
    # should use the class method resolve_version to determine this
    # before constructing a fetcher.
    attr_reader :resolved_version

    #
    # The upstream version as described before resolution.
    #
    # @return [String]
    #
    # This will usually be the same as +resolved_version+ but may
    # refer toa remote ref name or tag for a source such as git.
    attr_reader :described_version

    #
    # The path where fetched software should live.
    #
    # Only files under this directory are modified. If the source to fetch
    # is a directory, it is staged rooted here. If it's a file, it's copied
    # underneath this directory. If it's a tarball, it's extracted here. If
    # it's a repo, its checkout is rooted here. You get the idea.
    #
    # It's named project_dir instead of extract_dir/extract_path because of
    # legacy reasons. This has nothing to do with project definitions or the
    # underlying relative_path for a software definition (except for legacy
    # behavior).
    #
    # @return [String]
    #
    attr_reader :project_dir
    attr_reader :build_dir
    attr_reader :sources_dir

    #
    # Create a new Fetcher object from the given software.
    #
    # The parameters correspond to the relevant portions of a software
    # definition that a fetcher needs access to. This avoids strongly coupling
    # the software object with all fetchers.
    #
    # @param [ManifestEntry] manifest_entry
    # @param [String] project_dir
    # @param [String] build_dir
    # @param [String] sources_dir
    #
    def initialize(manifest_entry, project_dir, build_dir, sources_dir)
      @name    = manifest_entry.name
      @source  = manifest_entry.locked_source
      @resolved_version = manifest_entry.locked_version
      @described_version = manifest_entry.described_version
      @project_dir = project_dir
      @build_dir = build_dir
      @sources_dir = sources_dir
    end

    #
    # @!group Abstract methods
    #
    # The following methods are all abstract and should be overriden in child
    # classes.
    # --------------------------------------------------

    #
    # @abstract
    #
    def fetch_required?
      raise NotImplementedError
    end

    #
    # @abstract
    #
    def clean
      raise NotImplementedError
    end

    #
    # @abstract
    #
    def fetch
      raise NotImplementedError
    end

    #
    # @abstract
    #
    def version_guid
      raise NotImplementedError
    end

    #
    # @abstract
    #
    def version_for_cache
      raise NotImplementedError
    end

    #
    # @!endgroup
    # --------------------------------------------------

    def fetcher
      self
    end

    #
    # All fetchers should prefer resolved_version to version
    # this is provided for compatibility.
    #
    def version
      resolved_version
    end

    private

    #
    # Override the +log_key+ for this fetcher to include the name of the
    # software during the fetch.
    #
    # @return [String]
    #
    def log_key
      @log_key ||= "#{super}: #{name}"
    end

    #
    # Idempotently create the required directories for building/downloading.
    # Fetchers should call this method before performing any operations that
    # manipulate the filesystem.
    #
    # @return [void]
    #
    def create_required_directories
      [
        Config.cache_dir,
        Config.source_dir,
        build_dir,
        project_dir,
      ].each do |directory|
        FileUtils.mkdir_p(directory) unless File.directory?(directory)
      end
    end

    # Class Methods
    def self.resolve_version(version, source)
      fetcher_class_for_source(source).resolve_version(version, source)
    end

    def self.fetcher_class_for_source(source)
      if source
        if source[:url]
          NetFetcher
        elsif source[:git]
          GitFetcher
        elsif source[:path]
          PathFetcher
        end
      else
        NullFetcher
      end
    end
  end
end
