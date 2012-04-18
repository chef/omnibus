#
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# License:: Apache License, Version 2.0
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

    def fetch_required?
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
      if fetch_required?
        download
        verify_checksum!
      else
        log "Cached copy of source tarball up to date"
      end
    end

    def get_with_redirect(url, headers, limit = 10)
      raise ArgumentError, 'HTTP redirect too deep' if limit == 0
      log "getting #{project_file} from #{url} with #{limit} redirects left"

      if !url.kind_of?(URI)
        url = URI.parse(url) 
      end

      req = Net::HTTP::Get.new(url.path, headers)
      http_client = Net::HTTP.new(url.host, url.port)
      http_client.use_ssl = (url.scheme == "https")
    
      response = http_client.start { |http| http.request(req) }
      final_response = case response
                       when Net::HTTPSuccess     then response
                       when Net::HTTPRedirection then get_with_redirect(response['location'], headers, limit - 1)
                       else
                         response.error!
                       end
      open(project_file, "wb") do |f|
        f.write(final_response.body)
      end
      true
    end

    def download
      log source[:warning] if source.has_key?(:warning)
      log "fetching #{project_file} from #{source_uri}"

      case source_uri.scheme
      when /https?/
        headers = { 
          'accept-encoding' => '',
        }
        if source.has_key?(:cookie)
          headers['Cookie'] = source[:cookie]
        end
        get_with_redirect(source_uri, headers)
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
      shell = Mixlib::ShellOut.new("gzip -dc #{project_file} | tar -xf - -C #{source_dir}", :live_stream => STDOUT)
      shell.run_command
      shell.error!
    rescue Exception => e
      ErrorReporter.new(e, self).explain("Failed to unpack tarball at #{project_file} (#{e.class}: #{e.message.strip})")
      raise
    end

  end
end
