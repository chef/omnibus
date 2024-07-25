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

require "fileutils"
require "omnibus/download_helpers"

module Omnibus
  class ArtifactoryFetcher < NetFetcher
    private

    #
    # A find_url is required if the search in artifactory is required to find its file name
    #
    # @return [String]
    #
    def find_source_url
      require "base64"
      require("digest")
      require("artifactory")

      log.info(:info) { "Searching Artifactory for #{source[:path]}/#{source[:filename_pattern]} in #{source[:repository]} " }

      endpoint = source[:endpoint] || ENV["ARTIFACTORY_ENDPOINT"] || nil
      raise "Artifactory endpoint not configured" if endpoint.nil?

      Artifactory.endpoint = endpoint
      Artifactory.api_key  = source[:authorization ] if source[:authorization]

      unless source.key?(:authorization)
        username = ENV["ARTIFACTORY_USERNAME"] || nil
        password = ENV["ARTIFACTORY_PASSWORD"] || nil
        error_message = "You have to provide either source[:authorization] or environment variables for artifactory client"
        raise error_message if username.nil? || password.nil?

        source[:authorization] = "Basic #{Base64.encode64("#{username}:#{password}")}"
      end

      query = <<~EOM
        items.find(
          {
            "repo": {"$eq":"#{source[:repository]}"},
            "name": {"$match":"#{source[:filename_pattern]}"},
            "path": {"$match":"#{source[:path]}"}
          }
        ).include("name", "repo", "created", "path", "actual_sha1").sort({"$desc" : ["created"]}).limit(1)
      EOM
      result = Artifactory.post("/api/search/aql", query, "Content-Type" => "text/plain")
      results = result["results"]

      log.debug(:debug) { "Search Result #{result}" }

      raise "Unable to find #{source[:filename_pattern]} in #{source[:repository]}" if results.empty?

      artifact = results[0]

      source[:url] = "#{Artifactory.endpoint}/#{artifact['repo']}/#{artifact['path']}/#{artifact['name']}"
      source[:sha1] = artifact["actual_sha1"]

      log.info(:info) { "Found Artifact #{source[:url]} #{source[:sha1]}" }
    end

    #
    # The path on disk to the downloaded asset. The filename is defined by
    # +source :cached_name+. If ommited, then it comes from the software's
    # +source :url+ value or from the artifactory search result for newest
    # artifact
    #
    # @return [String]
    #
    def downloaded_file
      unless source.key?(:url)
        find_source_url
      end

      filename = source[:cached_name] if source[:cached_name]
      filename ||= File.basename(source[:url], "?*")
      File.join(Config.cache_dir, filename)
    end
  end
end
