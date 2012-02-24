require 'singleton'

module Omnibus

  class Config
    include Singleton

    attr_accessor :cache_dir

    attr_accessor :s3_bucket
    attr_accessor :s3_access_key
    attr_accessor :s3_secret_key

    attr_accessor :use_s3_caching

  end

  def self.config
    Config.instance
  end

  def self.configure
    yield config
  end

end

