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

module Omnibus
  class Software
    include Rake::DSL

    NULL_ARG = Object.new

    attr_reader :name
    attr_reader :description
    attr_reader :dependencies

    def initialize(io)
      @build_commands = []
      @dependencies = ["preparation"]
      instance_eval(io)
      render_tasks
    end

    def name(val)
      @name = val
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

    def relative_path(val)
      @relative_path = val
    end

    def source_uri
      @source_uri ||= URI(@source[:url])
    end

    def source_dir
      "/tmp/omnibus/src".freeze
    end

    def cache_dir
      "/tmp/omnibus/cache".freeze
    end

    def build_dir
      "/tmp/omnibus/build".freeze
    end

    def project_file
      filename = source_uri.path.split('/').last
      "#{cache_dir}/#{filename}"
    end

    def project_dir
      @relative_path ? "#{source_dir}/#{@relative_path}" : "#{source_dir}/#{@name}"
    end

    def manifest_file
      "#{build_dir}/#{@name}.manifest"
    end

    #
    # TODO: this doesn't actually give us any benefit over simply
    # calling #command from the software file, but I think it's cute
    #
    def build(&block)
      yield
    end

    private

    def command(*args)
      @build_commands << args
    end

    def platform
      OHAI.platform
    end

    def render_tasks
      namespace :software do

        #
        # set up inter-project dependencies
        #
        task @name => (@dependencies - [@name]).uniq

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
            builder = Builder.new(@build_commands, project_dir)
            builder.build

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
      end
    end
  end
end
