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
    # The software for this fetcher.
    #
    # @return [Software]
    #
    attr_reader :software

    #
    # Create a new Fetcher object from the given software.
    #
    # @param [Software] software
    #   the software to create this fetcher
    #
    def initialize(software)
      @software = software
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

    private

    #
    # The "source" for this software, with applied overrides.
    #
    # @return [Hash]
    #
    def source
      software.source
    end

    #
    # The path where extracted software should live.
    #
    # @see Software#project_dir
    #
    # @return [String]
    #
    def project_dir
      software.project_dir
    end

    #
    # The version for this sfotware, with applied overrides.
    #
    # @return [String]
    #
    def version
      software.version
    end

    #
    # Override the +log_key+ for this fetcher to include the name of the
    # software during the fetch.
    #
    # @return [String]
    #
    def log_key
      @log_key ||= "#{super}: #{software.name}"
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
        software.build_dir,
        software.project_dir,
      ].each do |directory|
        FileUtils.mkdir_p(directory) unless File.directory?(directory)
      end
    end
  end
end
