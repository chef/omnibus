#
# omnibus software dsl reader
#

require 'digest/md5'
require 'mixlib/shellout'
require 'net/ftp'
require 'net/http'
require 'net/https'
require 'uri'

require 'omnibus/fetcher'
require 'omnibus/builder'
require 'omnibus/config'

module Omnibus
  class Software
    include Rake::DSL

    NULL_ARG = Object.new

    attr_reader :description
    attr_reader :dependencies
    attr_reader :fetcher

    def self.load(filename)
      new(IO.read(filename), filename)
    end

    def initialize(io, filename)
      @version        = nil
      @name           = nil
      @description    = nil
      @source         = nil
      @relative_path  = nil
      @source_uri     = nil
      @source_config  = filename

      @builder = NullBuilder.new(self)

      @dependencies = ["preparation"]
      instance_eval(io, filename, 0)
      render_tasks
    end

    def name(val=NULL_ARG)
      @name = val unless val.equal?(NULL_ARG)
      @name
    end

    def description(val)
      @description = val
    end

    def dependencies(deps)
      deps.each do |dep|
        @dependencies << dep
      end
    end

    def source(val=NULL_ARG)
      @source = val unless val.equal?(NULL_ARG)
      @source
    end

    def version(val=NULL_ARG)
      @version = val unless val.equal?(NULL_ARG)
      @version
    end

    def relative_path(val)
      @relative_path = val
    end

    def source_uri
      @source_uri ||= URI(@source[:url])
    end

    def checksum
      @source[:md5]
    end

    def config
      Omnibus.config
    end

    def source_dir
      config.source_dir
    end

    def cache_dir
      config.cache_dir
    end

    def build_dir
      "#{config.build_dir}/#{camel_case_path(install_dir)}"
    end

    def max_build_jobs
      if OHAI.cpu == nil
        2
      else
        OHAI.cpu[:total] + 1
      end
    end

    def install_dir
      config.install_dir
    end

    def project_file
      filename = source_uri.path.split('/').last
      "#{cache_dir}/#{filename}"
    end

    def project_dir
      @relative_path ? "#{source_dir}/#{@relative_path}" : "#{source_dir}/#{@name}"
    end

    def manifest_file
      manifest_file_from_name(@name)
    end

    def manifest_file_from_name(software_name)
      "#{build_dir}/#{software_name}.manifest"
    end

    def fetch_file
      "#{build_dir}/#{@name}.fetch"
    end

    def camel_case_path(path)
      # split the path and remove and empty strings
      parts = path.split("/") - [""]
      parts.join("_")
    end

    def build(&block)
      @builder = Builder.new(self, &block)
    end

    def platform
      OHAI.platform
    end

    private

    def command(*args)
      raise "Method Moved."
    end

    def execute_build(fetcher)
      fetcher.clean
      @builder.build
      touch manifest_file
    end

    def render_tasks
      namespace :software do
        fetcher = Fetcher.for(self)

        #
        # set up inter-project dependencies
        #
        (@dependencies - [@name]).uniq.each do |dep|
          task @name => dep
          file manifest_file => manifest_file_from_name(dep)  
        end

        directory source_dir
        directory cache_dir
        directory build_dir
        directory project_dir
        namespace @name do
          task :fetch => [ build_dir, source_dir, cache_dir, project_dir ] do
            if !File.exists?(fetch_file) || fetcher.fetch_required?
              # force build to run if we need to do an updated fetch
              fetcher.fetch
              touch fetch_file
            end
          end

          task :build => :fetch do
            if uptodate?(manifest_file, [fetch_file])
              # if any deps have been built for any reason, we will need to
              # clean/build ourselves
              (@dependencies - [@name]).uniq.each do |dep|
                unless uptodate?(manifest_file, [manifest_file_from_name(dep)])
                  execute_build(fetcher)
                  break
                end
              end

            else 
              # if fetch has occurred, do a clean and build.
              execute_build(fetcher)
            end
          end
        end

        #
        # make the manifest file dependent on the latest file in the
        # source tree in order to shrink the multi-thousand-node
        # dependency graph that Rake was generating
        #
        latest_file = FileList["#{project_dir}/**/*"].sort { |a,b|
          File.mtime(a) <=> File.mtime(b)
        }.last

        file manifest_file => (file latest_file)

        file fetch_file => "#{name}:fetch" 
        file manifest_file => "#{name}:build"

        file fetch_file => (file @source_config)
        file manifest_file => (file fetch_file)

        desc "fetch and build #{@name}"
        task @name => manifest_file
      end
    end
  end
end
