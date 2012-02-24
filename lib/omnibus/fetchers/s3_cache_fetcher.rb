require 'omnibus/fetcher'
require 'omnibus/s3_cacher'

module Omnibus
  class S3CacheFetcher < NetFetcher
    include SoftwareS3URLs

    name :s3cache

    def initialize(software)
      @software = software
      super
    end

    def fetch
      log "Fetching cached version from S3"
      super
    end

    def source_uri
      URI.parse(url_for(@software))
    end
  end
end

