require 'rake/clean'
CLEAN.include('/tmp/omnibus/**/*')
CLOBBER.include('/opt/opscode/**/*')

require 'ohai'
o = Ohai::System.new
o.require_plugin('os')
o.require_plugin('platform')
OHAI = o

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
require 'net/ftp'
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

          #
          # source download
          #
          @source_task = task :source => [source_dir, cache_dir] do
            #
            # we don't need to download / checkout source if there
            # isn't any specified
            #
            next unless @source

            if @source[:url]
              #
              # fetch needed?
              #
              to_fetch = !File.exists?(project_file) || Digest::MD5.file(project_file) != @source[:md5]
              if to_fetch
                puts "fetching the source"
                case @source_uri.scheme
                when "http"
                  Net::HTTP.start(@source_uri.host) do |http|
                    resp = http.get(@source_uri.path, 'accept-encoding' => '')
                    open(project_file, "wb") do |f|
                      f.write(resp.body)
                    end
                  end
                when "ftp"
                  Net::FTP.open(@source_uri.host) do |ftp|
                    ftp.passive = true
                    ftp.login
                    ftp.getbinaryfile(@source_uri.path, project_file)
                    ftp.close
                  end
                else
                  raise
                end
                puts "extracting the source"
                shell = Mixlib::ShellOut.new("tar -x -f #{project_file} -C #{source_dir}", :live_stream => STDOUT)
                shell.run_command
                shell.error!
              end
            elsif @source[:git]
              #
              # clone needed?
              #
              to_clone = !File.directory?(project_dir) # TODO: check for .git file
              if to_clone
                puts "cloning the source from git"
                clone_cmd = "git clone #{@source[:git]} #{project_dir}"
                shell = Mixlib::ShellOut.new(clone_cmd, :live_stream => STDOUT)
                shell.run_command
                shell.error!
              end

              #
              # checkout needed?
              #
              to_checkout = true
              if to_checkout

              end
            end
          end

          #
          # keep track of the build manifest
          #
          file manifest_file => build_dir do
            puts "building the source"
            @build_commands.each do |cmd|
              cmd_args = Array(cmd)
              options = {
                :cwd => project_dir,
                :live_stream => STDOUT,
                :timeout => 3600
              }
              if cmd_args.last.is_a? Hash
                cmd_args.last.merge!(options)
              else
                cmd_args << options
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

        file manifest_file => @source_task
      end
    end
  end
end

FileList['config/software/*.rb'].each do |f|
  Omnibus::Software.new(IO.read(f))
end

