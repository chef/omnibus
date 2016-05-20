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

require "uri"
require "benchmark"

module Omnibus
  class ArtifactoryPublisher < Publisher
    def publish(&block)
      log.info(log_key) { "Starting artifactory publisher" }
      safe_require("artifactory")

      packages.each do |package|
        # Make sure the package is good to go!
        log.debug(log_key) { "Validating '#{package.name}'" }
        package.validate!

        retries = Config.publish_retries

        begin
          upload_time = Benchmark.realtime do
            remote_path = remote_path_for(package)
            properties  = default_properties.merge(metadata_properties_for(package))

            # Upload the package
            log.info(log_key) { "Uploading '#{package.name}'" }
            artifact_for(package).upload(
              repository,
              remote_path,
              properties
            )
            # Upload the package's assoacited `*.metadata.json` file
            log.info(log_key) { "Uploading '#{package.name}.metadata.json'" }
            artifact_for(package.metadata).upload(
              repository,
              "#{remote_path}.metadata.json",
              # *.metadata.json files should not include
              # the checksum properties
              properties.dup.delete_if { |k, v| k =~ /^omnibus\.(md5|sha)/ }
            )
          end
        rescue Artifactory::Error::HTTPError => e
          if (retries -= 1) != 0
            log.info(log_key) { "Upload failed with exception: #{e}" }
            log.info(log_key) { "Retrying failed publish #{retries} more time(s)..." }
            retry
          else
            raise e
          end
        end

        log.debug(log_key) { "Elapsed time to publish #{package.name}:  #{1000 * upload_time} ms" }

        # If a block was given, "yield" the package to the caller
        yield(package) if block
      end

      if build_record?
        if packages.empty?
          log.warn(log_key) { "No packages were uploaded, build record will not be created." }
        else
          build_for(packages).save
        end
      end
    end

    private

    #
    # The artifact object that corresponds to this package.
    #
    # @param [Package,Metadata] artifact
    #   the package or metadata file to create the artifact from
    #
    # @return [Artifactory::Resource::Artifact]
    #
    def artifact_for(artifact)
      md5  = artifact.respond_to?(:metadata) ? artifact.metadata[:md5] : digest(artifact.path, :md5)
      sha1 = artifact.respond_to?(:metadata) ? artifact.metadata[:sha1] : digest(artifact.path, :sha1)

      Artifactory::Resource::Artifact.new(
        local_path: artifact.path,
        client:     client,
        checksums: {
          "md5"  => md5,
          "sha1" => sha1,
        }
      )
    end

    #
    # The build object that corresponds to this package.
    #
    # @param [Array<Package>] packages
    #   the packages to create the build from
    #
    # @return [Artifactory::Resource::Build]
    #
    def build_for(packages)
      metadata = packages.first.metadata
      name     = metadata[:name]

      # Attempt to load the version manifest data from the packages metadata
      manifest = if version_manifest = metadata[:version_manifest]
                   Manifest.from_hash(version_manifest)
                 else
                   Manifest.new(
                     metadata[:version],
                     # we already know the `version_manifest` entry is
                     # missing so we can't pull in the `build_git_revision`
                     nil,
                     metadata[:license]
                   )
                 end

      # Upload the actual package
      log.info(log_key) { "Saving build info for #{name}, Build ##{manifest.build_version}" }

      Artifactory::Resource::Build.new(
        client: client,
        name:   name,
        number: manifest.build_version,
        vcs_revision: manifest.build_git_revision,
        build_agent: {
          name: "omnibus",
          version: Omnibus::VERSION,
        },
        properties: default_properties.merge(
          "omnibus.project"            => name,
          "omnibus.version"            => manifest.build_version,
          "omnibus.build_git_revision" => manifest.build_git_revision,
          "omnibus.license"            => manifest.license
        ),
        modules: [
          {
            # com.getchef:chef-server:12.0.0
            id: [
              Config.artifactory_base_path.tr("/", "."),
              name,
              manifest.build_version,
            ].join(":"),
            artifacts: packages.map do |package|
              [
                {
                  type: File.extname(package.path).split(".").last,
                  sha1: package.metadata[:sha1],
                  md5:  package.metadata[:md5],
                  name: package.metadata[:basename],
                },
                {
                  type: File.extname(package.metadata.path).split(".").last,
                  sha1: digest(package.metadata.path, :sha1),
                  md5:  digest(package.metadata.path, :md5),
                  name: File.basename(package.metadata.path),
                },
              ]
            end.flatten,
          },
        ]
      )
    end

    #
    # Indicates if an Artifactory build record should be created for the
    # published set of packages.
    #
    # @return [Boolean]
    #
    def build_record?
      # We want to create a build record by default
      if @options[:build_record].nil?
        true
      else
        @options[:build_record]
      end
    end

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
        proxy_port:     Config.artifactory_proxy_port
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
    def metadata_properties_for(package)
      metadata = {
        "omnibus.project"          => package.metadata[:name],
        "omnibus.platform"         => package.metadata[:platform],
        "omnibus.platform_version" => package.metadata[:platform_version],
        "omnibus.architecture"     => package.metadata[:arch],
        "omnibus.version"          => package.metadata[:version],
        "omnibus.iteration"        => package.metadata[:iteration],
        "omnibus.license"          => package.metadata[:license],
        "omnibus.md5"              => package.metadata[:md5],
        "omnibus.sha1"             => package.metadata[:sha1],
        "omnibus.sha256"           => package.metadata[:sha256],
        "omnibus.sha512"           => package.metadata[:sha512],
      }.tap do |h|
        if build_record?
          h["build.name"] = package.metadata[:name]
          h["build.number"] = package.metadata[:version]
        end
      end

      metadata
    end

    #
    # Properties to attach to published artifacts (and build record).
    #
    # @return [Hash<String, String>]
    #
    def default_properties
      @properties ||= @options[:properties] || {}
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
    #   chef/11.6.0/chef-11.6.0-1.el6.x86_64.rpm
    #
    # @param [Package] package
    #   the package to generate the remote path for
    #
    # @return [String]
    #
    def remote_path_for(package)
      File.join(
        Config.artifactory_base_path,
        package.metadata[:name],
        package.metadata[:version],
        package.metadata[:platform],
        package.metadata[:platform_version],
        package.metadata[:basename]
      )
    end
  end
end
