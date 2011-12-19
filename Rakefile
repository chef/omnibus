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

    attr_reader :sourcedir
    attr_reader :sourcefile
    attr_reader :cachedir

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
          #
          # source file download
          #
          sourcetask(@source)

          #
          # keep track of the build manifest
          #
          directory "tmp/build"
          file "tmp/build/#{@name}.manifest" => "tmp/build" do |t|
            puts "building the source"
            @build_commands.each do |cmd|
              cmd_args = *cmd
              cwd = {:cwd => 'tmp/src/zlib-1.2.5', :live_stream => STDOUT}
              if cmd_args.last.is_a? Hash
                cmd_args.last.merge!(cwd)
              else
                cmd_args << cwd
              end
              Mixlib::ShellOut.new(*cmd).run_command
            end
            # TODO: write the actual manifest file
            touch t.name
          end
          FileList["tmp/src/zlib-1.2.5/**/*"].each do |src|
            file "tmp/build/#{@name}.manifest" => src
          end
        end

        desc "fetch and build #{@name}"
        task @name => "tmp/build/#{@name}.manifest"
        file "tmp/build/#{@name}.manifest" => :source
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

