#
# Copyright 2012-2014 Chef Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
module Omnibus
  class UnsupportedURIScheme < ArgumentError
  end

  class InvalidSourceFile < RuntimeError
  end

  # Fetcher Implementation for HTTP and FTP hosted tarballs
  class NetFetcher < Fetcher
    attr_reader :name
    attr_reader :project_file
    attr_reader :source
    attr_reader :source_uri
    attr_reader :source_dir
    attr_reader :project_dir

    # Use 7-zip to extract 7z/zip for Windows
    WIN_7Z_EXTENSIONS = %w(.7z .zip)

    # tar probably has compression scheme linked in, otherwise for tarballs
    TAR_EXTENSIONS = %w(.tar .tar.gz .tgz .bz2 .tar.xz .txz)

    def initialize(software)
      @name         = software.name
      @checksum     = software.checksum
      @source       = software.source
      @project_file = software.project_file
      @source_uri   = software.source_uri
      @source_dir   = software.source_dir
      @project_dir  = software.project_dir
      super
    end

    def description
      <<-EOH.gsub(/^ {8}/, '').strip
        source URI:     #{source_uri}
        checksum:       #{@checksum}
        local location: #{@project_file}
      EOH
    end

    def version_guid
      "md5:#{@checksum}"
    end

    def fetch_required?
      !File.exist?(project_file) || Digest::MD5.file(project_file) != @checksum
    end

    def clean
      if File.exist?(project_dir)
        log.info(log_key) { "Cleaning existing build from #{project_dir}" }

        FileUtils.rm_rf(project_dir)
      end
      extract
    end

    def fetch
      if fetch_required?
        download
        verify_checksum!
      else
        log.debug(log_key) { 'Cached copy of source tarball up to date' }
      end
    end

    def get_with_redirect(url, headers, limit = 10)
      raise ArgumentError, 'HTTP redirect too deep' if limit == 0
      log.info(log_key) { "Getting from #{url} with #{limit} redirects left" }

      url = URI.parse(url) unless url.kind_of?(URI)

      req = Net::HTTP::Get.new(url.request_uri, headers)

      http_client = if http_proxy && !excluded_from_proxy?(url.host)
                      Net::HTTP::Proxy(http_proxy.host, http_proxy.port, http_proxy.user, http_proxy.password).new(url.host, url.port)
                    else
                      Net::HTTP.new(url.host, url.port)
                    end
      http_client.use_ssl = (url.scheme == 'https')

      response = http_client.start { |http| http.request(req) }
      case response
      when Net::HTTPSuccess
        open(project_file, 'wb') do |f|
          f.write(response.body)
        end
      when Net::HTTPRedirection
        get_with_redirect(response['location'], headers, limit - 1)
      else
        response.error!
      end
    end

    # search environment variable as given, all lowercase and all upper case
    def get_env(name)
      ENV[name] || ENV[name.downcase] || ENV[name.upcase] || nil
    end

    # constructs a http_proxy uri from HTTP_PROXY* env vars
    def http_proxy
      @http_proxy ||= begin
        proxy = get_env('HTTP_PROXY') || return
        proxy = "http://#{proxy}" unless proxy =~ /^https?:/
        uri = URI.parse(proxy)
        uri.user ||= get_env('HTTP_PROXY_USER')
        uri.password ||= get_env('HTTP_PROXY_PASS')
        uri
      end
    end

    # return true if the host is excluded from proxying via the no_proxy directive.
    # the 'no_proxy' variable contains a list of host suffixes separated by comma
    # example: example.com,www.examle.org,localhost
    def excluded_from_proxy?(host)
      no_proxy = get_env('no_proxy') || ''
      no_proxy.split(/\s*,\s*/).any? { |pattern| host.end_with? pattern }
    end

    def download
      tries = 5
      begin
        log.warn(log_key) { source[:warning] } if source.key?(:warning)
        log.info(log_key) { "Fetching #{project_file} from #{source_uri}" }

        case source_uri.scheme
        when /https?/
          headers = {
            'accept-encoding' => '',
          }
          if source.key?(:cookie)
            headers['Cookie'] = source[:cookie]
          end
          get_with_redirect(source_uri, headers)
        when 'ftp'
          Net::FTP.open(source_uri.host) do |ftp|
            ftp.passive = true
            ftp.login
            ftp.getbinaryfile(source_uri.path, project_file)
            ftp.close
          end
        else
          raise UnsupportedURIScheme, "Don't know how to download from #{source_uri}"
        end
      rescue Exception
        tries -= 1
        if tries != 0
          log.debug(log_key) { "Retrying failed download (#{tries})..." }
          retry
        else
          raise
        end
      end
    rescue Exception => e
      ErrorReporter.new(e, self).explain("Failed to fetch source from #source_uri (#{e.class}: #{e.message.strip})")
      raise
    end

    def verify_checksum!
      actual_md5 = Digest::MD5.file(project_file)
      unless actual_md5 == @checksum
        log.warn(log_key) { "Invalid MD5 for #{@name}" }
        log.warn(log_key) { "Expected: #{@checksum}" }
        log.warn(log_key) { "Actual:   #{actual_md5}" }
        raise InvalidSourceFile, "Checksum of downloaded file #{project_file} doesn't match expected"
      end
    end

    def extract
      log.info(log_key) do
        "Extracting the source in '#{project_file}' to '#{source_dir}'"
      end

      cmd = extract_cmd
      case cmd
      when Proc
        cmd.call
      when String
        shellout!(cmd)
      else
        raise "Don't know how to extract command for #{cmd.class} class"
      end
    rescue Exception => e
      ErrorReporter.new(e, self).explain("Failed to unpack archive at #{project_file} (#{e.class}: #{e.message.strip})")
      raise
    end

    def extract_cmd
      if Ohai.platform == 'windows' && project_file.end_with?(*WIN_7Z_EXTENSIONS)
        "7z.exe x #{project_file} -o#{source_dir} -r -y"
      elsif Ohai.platform != 'windows' && project_file.end_with?('.7z')
        "7z x #{project_file} -o#{source_dir} -r -y"
      elsif Ohai.platform != 'windows' && project_file.end_with?('.zip')
        "unzip #{project_file} -d #{source_dir}"
      elsif project_file.end_with?(*TAR_EXTENSIONS)
        compression_switch = 'z' if project_file.end_with?('gz')
        compression_switch = 'j' if project_file.end_with?('bz2')
        compression_switch = 'J' if project_file.end_with?('xz')
        compression_switch = '' if project_file.end_with?('tar')
        "tar #{compression_switch}xf #{project_file} -C#{source_dir}"
      else
        # if we don't recognize the extension, simply copy over the file
        proc do
          log.debug(log_key) do
            "'#{project_file}' is not an archive. Copying to '#{project_dir}'..."
          end
          # WARNING: hack hack hack, no project dir yet
          FileUtils.mkdir_p(project_dir)
          FileUtils.cp(project_file, project_dir)
        end
      end
    end
  end
end
