module Omnibus

  # Fetcher Implementation for HTTP and FTP hosted tarballs
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

    def description
      s=<<-E
source URI:     #@source_uri
checksum:       #{@source[:md5]}
local location: #@project_file
E
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
    rescue Exception => e
      ErrorReporter.new(e, self).explain("Failed to fetch source from #@source_uri (#{e.class}: #{e.message.strip})")
      raise
    end

  end
end
