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

require 'digest/md5'
require 'mixlib/shellout'
require 'net/http'
require 'uri'

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
          task :source => [source_dir, cache_dir] do
            #
            # fetch needed?
            #
            to_fetch = !File.exists?(project_file) || Digest::MD5.file(project_file) != @source[:md5]
            if to_fetch
              puts "fetching the source"
              Net::HTTP.start(@source_uri.host) do |http|
                resp = http.get(@source_uri.path)
                open(project_file, "wb") do |f|
                  f.write(resp.body)
                end
              end

              puts "extracting the source"
              shell = Mixlib::ShellOut.new("tar -x -f #{project_file} -C #{source_dir}", :live_stream => STDOUT)
              shell.run_command
              shell.error!
            end
          end

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
  end
end

FileList['config/software/*.rb'].each do |f|
  Omnibus::Software.new(IO.read(f))
end

