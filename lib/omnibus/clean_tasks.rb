module Omnibus
  module CleanTasks
    extend Rake::DSL

    # TODO: at some point we may want more control over what exactly
    # it is that we clean up:
    #
    # * rake clean:cache
    # * rake clean:build
    # * rake clean:package
    # * etc...
    #
    def self.define!
      require 'rake/clean'

      ::CLEAN.include("#{config.source_dir}/**/*",
                      "#{config.build_dir}/**/*")

      ::CLOBBER.include("#{config.install_dir}/**/*",
                        "#{config.cache_dir}/**/*")
    end

    def self.config
      Omnibus.config
    end
  end
end
