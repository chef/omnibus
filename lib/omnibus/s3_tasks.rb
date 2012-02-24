module Omnibus
  module S3Tasks
    extend Rake::DSL

    def self.define!
      require 'uber-s3'

      namespace :s3 do
        desc "List source packages which have the correct source package in the S3 cache"
        task :existing do
          S3Cache.new.list.each {|s| puts s.name}
        end

        desc "List all cached files (by S3 key)"
        task :list do
          S3Cache.new.list_by_key.each {|k| puts k}
        end

        desc "Lists source packages that are required but not yet cached"
        task :missing do
          S3Cache.new.missing.each {|s| puts s.name}
        end

        desc "Fetches missing source packages to local tmp dir"
        task :fetch do
          S3Cache.new.fetch_missing
        end

        desc "Populate the S3 Cache"
        task :populate do
          S3Cache.new.populate
        end

      end
    rescue LoadError

      desc "S3 tasks not available"
      task :s3 do
        puts(<<-F)
The `uber-s3` gem is required to cache new source packages in S3.
F
      end
    end
  end
end
