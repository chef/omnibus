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

module Omnibus
  class NullFetcher < Fetcher
    #
    # @return [false]
    #
    def fetch_required?
      true
    end

    #
    # @return [nil]
    #
    def version_guid
      nil
    end

    #
    # @return [String, nil]
    #
    def self.resolve_version(version, source)
      version
    end

    #
    # @return [false]
    #
    def clean
      false
    end

    #
    # @return [void]
    #
    def fetch
      log.info(log_key) { "Fetching `#{name}' (nothing to fetch)" }

      create_required_directories
      nil
    end

    #
    # @return [String]
    #
    def version_for_cache
      nil
    end
  end
end
