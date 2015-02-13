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
    # The version this software should fetch.  For fetchers with
    # symbolic resolution of the actual version, this is used for
    # resolution.  The resolved_version is used during any fetching
    # and may be overriden with an argument
    #
    attr_reader :version

    #
    # The path where extracted software should live.
    #
    # @return [String]
    #
    attr_reader :project_dir
    attr_reader :build_dir

    #
    # Create a new Fetcher object from the given software.
    #
    # @param [Software] software
    #
    # To preserve the original interface, this still takes a software-like
    # argument, but to avoid coupling with the software object, we pull out
    # what we need and don't touch it again.
    def initialize(software)
      @name    = software.name
      @source  = software.source
      @version = software.version
      @project_dir = software.project_dir
      @build_dir = software.build_dir
    end

    def use_manifest_entry(manifest_entry)
      @source = manifest_entry.locked_source
      @resolved_version = manifest_entry.locked_version
    end

    def resolved_version
      @resolved_version ||= resolve_version
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
    def resolve_version
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
  end
end
