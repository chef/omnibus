require 'pp'

module Omnibus

  class Fetcher

    class ErrorReporter

      def initialize(error, fetcher)
        @error, @fetcher = error, fetcher
      end

      def e
        @error
      end

      def explain(why)
        $stderr.puts "* " * 40
        $stderr.puts why
        $stderr.puts "Fetcher params:"
        $stderr.puts indent(@fetcher.description, 2)
        $stderr.puts "Exception:"
        $stderr.puts indent("#{e.class}: #{e.message.strip}", 2)
        e.backtrace.each {|l| $stderr.puts indent(e.backtrace, 4) }
        $stderr.puts "* " * 40
      end

      private

      def indent(string, n)
        string.split("\n").map {|l| " ".rjust(n) << l }.join("\n")
      end

    end

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

    def description
      # Not as pretty as we'd like, but it's a sane default:
      inspect
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

  class GitFetcher < Fetcher

    attr_reader :source
    attr_reader :project_dir
    attr_reader :version

    def initialize(software)
      @source       = software.source
      @project_dir  = software.project_dir
      @version      = software.version
    end

    def description
      s=<<-E
repo URI:       #{@source[:git]}
local location: #{@project_dir}
E
    end

    def fetch
      if existing_git_clone?
        fetch_updates unless current_rev_matches_target_rev?
      else
        clone
        checkout
      end
    rescue Exception => e
      ErrorReporter.new(e, self).explain("Failed to fetch git repository '#{@source[:git]}'")
      raise
    end

    private

    def clone
      puts "cloning the source from git"
      clone_cmd = "git clone #{@source[:git]} #{project_dir}"
      shell = Mixlib::ShellOut.new(clone_cmd, :live_stream => STDOUT)
      shell.run_command
      shell.error!
    end

    def checkout
      sha_ref = target_revision

      checkout_cmd = "git checkout #{sha_ref}"
      shell = Mixlib::ShellOut.new(checkout_cmd, :live_stream => STDOUT, :cwd => project_dir)
      shell.run_command
      shell.error!
    end

    def fetch_updates
      puts "fetching updates and resetting to revision #{target_revision}"
      fetch_cmd = "git fetch origin && git fetch origin --tags && git reset --hard #{target_revision}"
      shell = Mixlib::ShellOut.new(fetch_cmd, :live_stream => STDOUT, :cwd => project_dir)
    end

    def existing_git_clone?
      File.exist?("#{project_dir}/.git")
    end

    def current_rev_matches_target_rev?
      current_revision && current_revision.strip.to_i(16) == target_revision.strip.to_i(16)
    end

    def current_revision
      @current_rev ||= begin
                         rev_cmd = "git rev-parse HEAD"
                         shell = Mixlib::ShellOut.new(rev_cmd, :live_stream => STDOUT, :cwd => project_dir)
                         shell.run_command
                         shell.error!
                         output = shell.stdout

                         sha_hash?(output) ? output : nil
                       end
    end

    def target_revision
      @target_rev ||= begin
                        if sha_hash?(version)
                          version
                        else
                          revision_from_remote_reference(version)
                        end
                      end
    end

    def sha_hash?(rev)
      rev =~ /^[0-9a-f]{40}$/
    end

    def revision_from_remote_reference(ref)
      # execute `git ls-remote`
      cmd = "git ls-remote origin #{ref}"
      shell = Mixlib::ShellOut.new(cmd, :live_stream => STDOUT, :cwd => project_dir)
      shell.run_command
      shell.error!
      stdout = shell.stdout

      # parse the output for the git SHA
      unless stdout =~ /^([0-9a-f]{40})\s+(\S+)/
        raise "Could not parse SHA reference"
      end
      return $1
    end
  end
end
