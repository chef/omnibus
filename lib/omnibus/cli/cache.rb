#
# Copyright:: Copyright (c) 2013-2014 Chef Software, Inc.
# License:: Apache License, Version 2.0
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

require 'omnibus/cli/base'
require 'omnibus/s3_cacher'

module Omnibus
  module CLI
    class Cache < Base
      class_option :path,
                   aliases: [:p],
                   type: :string,
                   default: Dir.pwd,
                   desc: 'Path to the Omnibus project root.'

      namespace :cache

      desc 'existing', 'List source packages which exist in the cache'
      def existing
        S3Cache.new.list.each { |s| puts s.name }
      end

      desc 'list', 'List all cached files (by S3 key)'
      def list
        S3Cache.new.list_by_key.each { |k| puts k }
      end

      desc 'missing', 'Lists source packages that are required but not yet cached'
      def missing
        S3Cache.new.missing.each { |s| puts s.name }
      end

      desc 'fetch', 'Fetches missing source packages to local tmp dir'
      def fetch
        S3Cache.new.fetch_missing
      end

      desc 'populate', 'Populate the S3 Cache'
      def populate
        S3Cache.new.populate
      end
    end
  end
end
