require 'singleton'

module Omnibus

  class Config
    include Singleton

    def self.default_values
      @default_values ||= []
    end

    def self.configurable(name, opts={})
      attr_accessor name
      default_values << [name, opts[:default]] if opts[:default]
    end

    def reset!
      self.class.default_values.each do |option, default|
        send("#{option}=", default)
      end
    end

    def initialize
      reset!
    end

    configurable :cache_dir, :default => "/tmp/omnibus/cache"
    configurable :source_dir, :default => "/tmp/omnibus/src"
    configurable :build_dir, :default => "/tmp/omnibus/build"
    configurable :install_dir, :default => "/opt/chef"

    configurable :use_s3_caching, :default => false

    configurable :s3_bucket
    configurable :s3_access_key
    configurable :s3_secret_key


  end

  def self.config
    Config.instance
  end

  def self.configure
    yield config
  end

end

