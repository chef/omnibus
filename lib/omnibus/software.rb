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

    def render_tasks
      namespace :software do

        #
        # set up inter-project dependencies
        #
        (@dependencies - [@name]).uniq.each do |dep|
          task @name => dep
          file manifest_file => manifest_file_from_name(dep)
        end

        namespace @name do

          directory source_dir
          directory cache_dir
          directory build_dir
          directory project_dir

          #
          # source download
          #
          @source_task = task :source => [source_dir, cache_dir, project_dir] do
            #
            # we don't need to download / checkout source if there
            # isn't any specified
            #
            if @source
              fetcher = Fetcher.for(self)
              fetcher.fetch
            else
              # touch a placeholder file
              placeholder = "#{project_dir}/placeholder"
              touch placeholder unless File.exist?(placeholder)
            end
          end

          #
          # keep track of the build manifest
          #
          file manifest_file => build_dir do
            @builder.build

            # TODO: write the actual manifest file
            touch manifest_file
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
        end

        desc "fetch and build #{@name}"
        task @name => manifest_file

        file manifest_file => @source_task
        file manifest_file => (file @source_config)
      end
    end
  end
end
