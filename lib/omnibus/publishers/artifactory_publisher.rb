#
# Copyright 2014 Chef Software, Inc.
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

require 'uri'

module Omnibus
  class ArtifactoryPublisher < Publisher
    def publish(&block)
      log.info(log_key) { 'Starting artifactory publisher' }
      safe_require('artifactory')

      packages.each do |package|
        # Make sure the package is good to go!
        log.debug(log_key) { "Validating '#{package.name}'" }
        package.validate!

        # Upload the actual package
        log.info(log_key) { "Uploading '#{package.name}'" }
        artifact = Artifactory::Resource::Artifact.new(local_path: package.path, client: client)
        artifact.upload_with_checksum(
          repository,
          remote_path_for(package),
          checksum_for(package),
          metadata_for(package),
        )

        # If a block was given, "yield" the package to the caller
        block.call(package) if block
      end
    end

    private

    #
    # The Artifactory client object to communicate with the Artifactory API.
    #
    # @return [Artifactory::Client]
    #
    def client
      @client ||= Artifactory::Client.new(
        endpoint:       Config.artifactory_endpoint,
        username:       Config.artifactory_username,
        password:       Config.artifactory_password,
        ssl_pem_file:   Config.artifactory_ssl_pem_file,
        ssl_verify:     Config.artifactory_ssl_verify,
        proxy_username: Config.artifactory_proxy_username,
        proxy_password: Config.artifactory_proxy_password,
        proxy_address:  Config.artifactory_proxy_address,
        proxy_port:     Config.artifactory_proxy_port,
      )
    end

    #
    # The metadata for this package.
    #
    # @param [Package] package
    #   the package to generate the metadata for
    #
    # @return [Hash<String, String>]
    #
    def metadata_for(package)
      {
        'omnibus.project'          => package.metadata[:name],
        'omnibus.platform'         => package.metadata[:platform],
        'omnibus.platform_version' => package.metadata[:platform_version],
        'omnibus.arch'             => package.metadata[:arch],
        'omnibus.version'          => package.metadata[:version],
        'omnibus.md5'              => package.metadata[:md5],
        'omnibus.sha1'             => package.metadata[:sha1],
        'omnibus.sha256'           => package.metadata[:sha256],
        'omnibus.sha512'           => package.metadata[:sha512],
      }
    end

    #
    # The checksum to pass to artifactory to validate the uploaded artifact.
    #
    # @param [Package] package
    #   the package to generate the checksum for
    #
    # @return [String]
    #
    def checksum_for(package)
      package.metadata[:sha1]
    end

    #
    # The name of the Artifactory repository (as supplied as an option).
    #
    # @return [String]
    #
    def repository
      @options[:repository]
    end

    #
    # The path where the package will live inside of the Artifactory repository.
    # This is dynamically computed from the values in the project definition
    # and the package metadata.
    #
    # @example
    #   com/getchef/chef/11.6.0/chef-11.6.0-1.el6.x86_64.rpm
    #
    # @param [Package] package
    #   the package to generate the remote path for
    #
    # @return [String]
    #
    def remote_path_for(package)
      unless package.metadata[:homepage]
        raise OldMetadata.new(package.metadata.path)
      end

      domain_parts = parsed_uri_for(package).host.split('.')
      domain_parts.delete('www')
      domain_parts.reverse!

      File.join(
        *domain_parts,
        package.metadata[:name],
        package.metadata[:version],
        package.metadata[:basename],
      )
    end

    #
    # The parsed domain for this package. Ruby's URI parser does not "assume"
    # a valid protocol, so passing a URI like "CHANGEME.org" will essentially
    # result in an unsable object that has no useful, extractable information.
    #
    # This method will essentially "force" a default protocol on the +homepage+
    # attribute of the package, so that it can be parsed like a good little URI.
    #
    # @param [Package] package
    #   the package to generate the remote path for
    #
    # @return [URI]
    #   the parsed URI object
    #
    def parsed_uri_for(package)
      raw = package.metadata[:homepage]

      if raw =~ /\Ahttps?:\/\//
        URI.parse(raw)
      else
        URI.parse("http://#{raw}")
      end
    end
  end
end
