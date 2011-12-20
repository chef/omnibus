#
# omnibus project dsl reader
#

module Omnibus
  class Project
    include Rake::DSL
  end
end

#
# omnibus software dsl reader
#

require 'mixlib/shellout'

module Omnibus
  class Software
    include Rake::DSL

    attr_reader :name
    attr_reader :description
    attr_reader :dependencies
    attr_reader :source

    def initialize(io)
      @build_commands = []
      instance_eval(io)
      render_tasks
    end

    def name(val)
      @name = val
    end

    def description(val)
      @description = val
    end

    def dependencies(val)
      @dependencies = val
    end

    def source(val)
      @source = val
    end

    def relative_path(val)
      @relative_path = val
    end

    def source_uri
      @source_uri ||= URI(@source[:url])
    end

    def source_dir
      "tmp/src".freeze
    end

    def cache_dir
      "tmp/cache".freeze
    end

    def build_dir
      "tmp/build".freeze
    end

    def project_file
      filename = source_uri.path.split('/').last
      "#{cache_dir}/#{filename}"
    end

    def project_dir
      "#{source_dir}/#{@relative_path}"
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

    def render_tasks
      namespace :software do
        namespace @name do

          directory source_dir
          directory cache_dir
          directory build_dir

          #
          # source file download
          #
          sourcetask(@source)

          #
          # keep track of the build manifest
          #
          file manifest_file => build_dir do
            puts "building the source"
            @build_commands.each do |cmd|
              cmd_args = *cmd
              cwd = {:cwd => project_dir, :live_stream => STDOUT}
              if cmd_args.last.is_a? Hash
                cmd_args.last.merge!(cwd)
              else
                cmd_args << cwd
              end
              shell = Mixlib::ShellOut.new(*cmd)
              shell.run_command
              shell.error!
            end
            # TODO: write the actual manifest file
            touch manifest_file
          end
          FileList["#{project_dir}/**/*"].each do |src|
            file manifest_file => src
          end
        end

        desc "fetch and build #{@name}"
        task @name => manifest_file
        file manifest_file => :source
      end
    end

    #
    # create a source task
    #
    def sourcetask(params)
      Omnibus::Tasks::SourceTask.define_task(:source).tap do |t|
        t.url = params[:url]
        t.md5 = params[:md5]

        file t.srcfile
        directory t.srcdir
        directory t.cachedir
        task :source => [t.srcdir, t.cachedir]
      end
    end
  end
end

module Omnibus
  module Tasks
    require 'uri'
    require 'digest/md5'
    require 'net/http'

    # -- SourceTask --
    #
    # Download some source code from teh internetz
    #
    class SourceTask < Rake::Task
      include Rake::DSL

      attr_accessor :url
      attr_accessor :md5

      def initialize(name, klass)
        super
        @actions << fetch_source
        @actions << extract_source
      end

      def needed?
        ! File.exist?(srcfile) || Digest::MD5.file(srcfile) != @md5
      end

      def uri
        @uri ||= URI(@url)
      end

      def filename
        uri.path.split('/').last
      end

      def srcfile
        "tmp/cache/#{filename}"
      end

      def cachedir
        "tmp/cache"
      end

      def srcdir
        "tmp/src"
      end

      def fetch_source
        Proc.new do
          puts "downloading #{uri}"
          Net::HTTP.start(uri.host) do |http|
            resp = http.get(uri.path)
            open(srcfile, "wb") do |f|
              f.write(resp.body)
            end
          end
        end
      end

      def extract_source
        Proc.new do
          puts "extracting #{srcfile}"
          sh "tar -x -f #{srcfile} -C #{srcdir}"
        end
      end
    end
  end
end

FileList['config/software/*.rb'].each do |f|
  Omnibus::Software.new(IO.read(f))
end

