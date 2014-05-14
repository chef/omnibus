#
# Copyright 2013-2014 Chef Software, Inc.
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
  class Command::Cache < Command::Base
    namespace :cache

    #
    # List the existing source packages in the cache.
    #
    #   $ omnibus cache existing
    #
    desc 'existing', 'List source packages which exist in the cache'
    def existing
      result = cache.list

      if result.empty?
        say('There are no packages in the cache!')
      else
        say('The following packages are in the cache:')
        result.each do |source|
          say("  * #{source.name}")
        end
      end
    end

    #
    # List all cached files (by S3 key).
    #
    #   $ omnibus cache list
    #
    desc 'list', 'List all cached files (by S3 key)'
    def list
      result = cache.list_by_key

      if result.empty?
        say('There is nothing in the cache!')
      else
        say('Cached files (by S3 key):')
        result.each do |key|
          say("  * #{key}")
        end
      end
    end

    #
    # List missing source packages.
    #
    #   $ omnibus cache missing
    #
    desc 'missing', 'Lists source packages that are required but not yet cached'
    def missing
      result = cache.missing

      if result.empty?
        say('There are no missing packages in the cache.')
      else
        say('The following packages are missing from the cache:')
        result.each do |source|
          say(source.name)
        end
      end
    end

    #
    # Fetch missing source packages locally
    #
    #   $ omnibus cache fetch
    #
    desc 'fetch', 'Fetches missing source packages locally'
    def fetch
      say('Fetching missing packages...')
      cache.fetch_missing
    end

    #
    # Populate the remote S3 cache from local.
    #
    #   $ omnibus cache populate
    #
    desc 'populate', 'Populate the S3 Cache'
    def populate
      say('Populating the cache...')
      cache.populate
    end

    private

    def cache
      @cache ||= S3Cache.new
    end
  end
end
