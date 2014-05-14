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
require 'uber-s3'

module Omnibus
  class S3Cache
    include Logging
    include SoftwareS3URLs

    def initialize
      unless config.s3_bucket && config.s3_access_key && config.s3_secret_key
        raise InvalidS3Configuration.new(config.s3_bucket, config.s3_access_key, config.s3_secret_key)
      end
      @client = UberS3.new(
        access_key: config.s3_access_key,
        secret_access_key: config.s3_secret_key,
        bucket: config.s3_bucket,
        adapter: :net_http,
      )
    end

    def config
      Omnibus.config
    end

    def list
      existing_keys = list_by_key
      tarball_software.select { |s| existing_keys.include?(key_for_package(s)) }
    end

    def list_by_key
      bucket.objects('/').map(&:key)
    end

    def missing
      already_cached = list_by_key
      tarball_software.delete_if { |s| already_cached.include?(key_for_package(s)) }
    end

    def tarball_software
      Omnibus.projects.map do |project|
        project.library.select { |s| s.source && s.source.key?(:url) }
      end.flatten
    end

    def populate
      missing.each do |software|
        fetch(software)

        key = key_for_package(software)
        content = IO.read(software.project_file)

        log.info(log_key) do
          "Uploading #{software.project_file} as #{config.s3_bucket}/#{key}"
        end

        @client.store(key, content, access: :public_read, content_md5: software.checksum)
      end
    end

    def fetch_missing
      missing.each do |software|
        fetch(software)
      end
    end

    private

    def ensure_cache_dir
      FileUtils.mkdir_p(config.cache_dir)
    end

    def fetch(software)
      log.info(log_key) { "Fetching #{software.name}" }
      fetcher = Fetcher.without_caching_for(software)
      if fetcher.fetch_required?
        log.debug(log_key) { 'Updating cache' }
        fetcher.download
        fetcher.verify_checksum!
      else
        log.debug(log_key) { 'Cached copy up to date, skipping.' }
      end
    end

    def bucket
      @bucket ||= begin
        if @client.exists?('/')
          @client.bucket
        else
          @client.connection.put('/')
        end
      end
    end
  end
end
