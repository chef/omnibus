module Omnibus

  class UnsupportedURIScheme < ArgumentError
  end

  class InvalidSourceFile < RuntimeError
  end

  # Fetcher Implementation for HTTP and FTP hosted tarballs
  class NetFetcher < Fetcher

    name :net

    attr_reader :name
    attr_reader :project_file
    attr_reader :source
    attr_reader :source_uri
    attr_reader :source_dir
    attr_reader :project_dir

    def initialize(software)
      @name         = software.name
      @checksum     = software.checksum
      @source       = software.source
      @project_file = software.project_file
      @source_uri   = software.source_uri
      @source_dir   = software.source_dir
      @project_dir  = software.project_dir
    end

    def description
      s=<<-E
source URI:     #{source_uri}
checksum:       #{@checksum}
local location: #@project_file
E
    end

    def should_download?
      !File.exists?(project_file) || Digest::MD5.file(project_file) != @checksum
    end

    def clean
      if File.exists?(project_dir) 
        log "cleaning existing build from #{project_dir}" 
        shell = Mixlib::ShellOut.new("rm -rf #{project_dir}", :live_stream => STDOUT)
        shell.run_command
        shell.error!
      end
      extract
    end

    def fetch
      if should_download?
        download
        verify_checksum!
      else
        log "Cached copy of source tarball up to date"
      end
    end

    def download
      log "fetching #{project_file} from #{source_uri}"

      case source_uri.scheme
      when /https?/
        http_client = Net::HTTP.new(source_uri.host, source_uri.port)
        http_client.use_ssl = (source_uri.scheme == "https")
        http_client.start do |http|
          resp = http.get(source_uri.path, 'accept-encoding' => '')
          open(project_file, "wb") do |f|
            f.write(resp.body)
          end
        end
      when "ftp"
        Net::FTP.open(source_uri.host) do |ftp|
          ftp.passive = true
          ftp.login
          ftp.getbinaryfile(source_uri.path, project_file)
          ftp.close
        end
      else
        raise UnsupportedURIScheme, "Don't know how to download from #{source_uri}"
      end
    rescue Exception => e
      ErrorReporter.new(e, self).explain("Failed to fetch source from #source_uri (#{e.class}: #{e.message.strip})")
      raise
    end

    def verify_checksum!
      actual_md5 = Digest::MD5.file(project_file)
      unless actual_md5 == @checksum
        log "Invalid MD5 for #@name"
        log "Expected: #{@checksum}"
        log "Actual:   #{actual_md5}"
        raise InvalidSourceFile, "Checksum of downloaded file #{project_file} doesn't match expected"
      end
    end

    def extract
      log "extracting the source in #{project_file} to #{source_dir}"
      shell = Mixlib::ShellOut.new("tar -x -f #{project_file} -C #{source_dir}", :live_stream => STDOUT)
      shell.run_command
      shell.error!
    rescue Exception => e
      ErrorReporter.new(e, self).explain("Failed to unpack tarball at #{project_file} (#{e.class}: #{e.message.strip})")
      raise
    end

  end
end
