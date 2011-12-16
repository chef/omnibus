module Omnibus
  module Tasks
    module DSL; end
  end
end

module Omnibus
  class Project
    include Rake::DSL


  end


  class Software
    include Rake::DSL
    include Omnibus::Tasks::DSL

    def initialize(io)
      instance_eval(io)
      render_tasks
    end

    def name(val)
      @name = val
    end

    def description(val)
      @description = val
    end

    def dependencies(arr)
      @dependencies = arr
    end

    def source(val)
      @source = val
    end

    def build(&block)
      # todo
    end

    def render_tasks
      namespace :software do
        namespace @name do
          #
          # source file download
          #
          sourcetask(@source)

          task :build do
            puts "building the source... not really "
          end
        end
        task "#{@name}:build" => "#{@name}:source"

        desc "fetch and build #{@name}"
        task @name => "#{@name}:build"
      end
    end
  end
end


module Omnibus
  module Tasks
    module DSL

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

software_file = <<-EOF
name "zlib"
description "teh zlibz"
dependencies []
source :url => "http://zlib.net/zlib-1.2.5.tar.gz",
       :md5 => "c735eab2d659a96e5a594c9e8541ad63"
EOF

Omnibus::Software.new(software_file)
