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
  class S3CacheFetcher < NetFetcher
    def fetch
      log.info(log_key) do
        "S3 Cache enabled, '#{name}' will be fetched from S3 cache"
      end

      super
    end

    #
    # The source URI for the software definition that is being fetched.
    #
    # @return [URI]
    #
    def source_uri
      URI.parse(url_for(@software))
    end

    private

    #
    # The URL for the cached software.
    #
    # @return [String]
    #
    def url_for(software)
      "http://#{Config.s3_bucket}.s3.amazonaws.com/#{S3Cache.key_for(software)}"
    end
  end
end
