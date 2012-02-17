require 'pp'

module Omnibus
  class Fetcher

    class UnsupportedSourceLocation < ArgumentError
    end


    def self.for(software)
      if software.source[:url]
        NetFetcher.new(software)
      elsif software.source[:git]
        GitFetcher.new(software)
      else
        raise UnsupportedSourceLocation, "Don't know how to fetch software project #{software}"
      end
    end

    def fetcher
      raise NotImplementedError, "define #fetcher for class #{self.class}"
    end

  end

  class NetFetcher < Fetcher

    attr_reader :project_file
    attr_reader :source
    attr_reader :source_uri
    attr_reader :source_dir


    def initialize(software)
      @source       = software.source
      @project_file = software.project_file
      @source_uri   = software.source_uri
      @source_dir   = software.source_dir
    end


    def fetch
      #
      # fetch needed?
      #
      to_fetch = !File.exists?(project_file) || Digest::MD5.file(project_file) != @source[:md5]
      if to_fetch
        puts "fetching the source"
        case @source_uri.scheme
        when /https?/
          http_client = Net::HTTP.new(@source_uri.host, @source_uri.port)
          http_client.use_ssl = (@source_uri.scheme == "https")
          http_client.start do |http|
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
    rescue Exception
      pp self
      raise
    end

  end

  class GitFetcher < Fetcher

    attr_reader :source
    attr_reader :project_dir

    def initialize(software)
      @source       = software.source
      @project_dir  = software.project_dir
    end

    def fetch
      #
      # clone needed?
      #
      to_clone = (!File.directory?(project_dir) ||
                  !File.directory?("#{project_dir}/.git"))
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
        # TODO: checkout the most up to date version
      end
    rescue Exception
      pp self
      raise
    end
  end

end
