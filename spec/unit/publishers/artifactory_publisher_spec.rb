require "spec_helper"

module Omnibus
  describe ArtifactoryPublisher do
    let(:path) { "/path/to/files/*.deb" }
    let(:repository) { "REPO" }

    let(:package) do
      double(Package,
        path: "/path/to/files/chef.deb",
        name: "chef.deb",
        content: "BINARY",
        validate!: true)
    end

    let(:metadata) do
      Metadata.new(package,
        name: "chef",
        friendly_name: "Chef",
        homepage: "https://www.getchef.com",
        version: "11.0.6",
        iteration: 1,
        license:  "Apache-2.0",
        basename: "chef.deb",
        platform: "ubuntu",
        platform_version: "14.04",
        arch: "x86_64",
        sha1: "SHA1",
        sha256: "SHA256",
        sha512: "SHA512",
        md5: "ABCDEF123456",
        version_manifest: {
          manifest_format: 1,
          build_version: "11.0.6",
          build_git_revision: "2e763ac957b308ba95cef256c2491a5a55a163cc",
          software: {
            zlib: {
              locked_source: {
                md5: "44d667c142d7cda120332623eab69f40",
                url: "http://iweb.dl.sourceforge.net/project/libpng/zlib/1.2.8/zlib-1.2.8.tar.gz",
              },
              locked_version: "1.2.8",
              source_type: "url",
              described_version: "1.2.8",
              license: "Zlib",
            },
            openssl: {
              locked_source: {
                md5: "562986f6937aabc7c11a6d376d8a0d26",
                extract: "lax_tar",
                url: "http://iweb.dl.sourceforge.net/project/libpng/zlib/1.2.8/zlib-1.2.8.tar.gz",
              },
              locked_version: "1.0.1s",
              source_type: "url",
              described_version: "1.0.1s",
              license: "OpenSSL",
            },
            ruby: {
              locked_source: {
                md5: "091b62f0a9796a3c55de2a228a0e6ef3",
                url: "https://cache.ruby-lang.org/pub/ruby/2.1/ruby-2.1.8.tar.gz",
              },
              locked_version: "2.1.8",
              source_type: "url",
              described_version: "2.1.8",
              license: "BSD-2-Clause",
            },
            ohai: {
              locked_source: {
                git: "https://github.com/chef/ohai.git",
              },
              locked_version: "fec0959aa5da5ce7ba0e07740dbc08546a8f53f0",
              source_type: "git",
              described_version: "master",
              license: "Apache-2.0",
            },
            chef: {
              locked_source: {
                path: "/home/jenkins/workspace/chef-build/architecture/x86_64/platform/ubuntu-10.04/project/chef/role/builder/omnibus/files/../..",
                options: {
                  exclude: [
                    "omnibus/vendor",
                  ],
                },
              },
              locked_version: "local_source",
              source_type: "path",
              described_version: "local_source",
              license: "Apache-2.0",
            },
          },
        })
    end

    let(:packages) { [package] }
    let(:client)   { double("Artifactory::Client") }
    let(:artifact) { double("Artifactory::Resource::Artifact", upload: nil) }
    let(:build)    { double("Artifactory::Resource::Build") }

    let(:package_properties) do
      {
        "omnibus.architecture" => "x86_64",
        "omnibus.iteration" => 1,
        "omnibus.md5" => "ABCDEF123456",
        "omnibus.platform" => "ubuntu",
        "omnibus.platform_version" => "14.04",
        "omnibus.project" => "chef",
        "omnibus.sha1" => "SHA1",
        "omnibus.sha256" => "SHA256",
        "omnibus.sha512" => "SHA512",
        "omnibus.version" => "11.0.6",
        "omnibus.license" => "Apache-2.0",
        "md5" => "ABCDEF123456",
        "sha1" => "SHA1",
        "sha256" => "SHA256",
        "sha512" => "SHA512",
      }
    end
    let(:metadata_json_properites) do
      # we don't attache checksum properties to the *.metadata.json
      package_properties.delete_if { |k, v| k =~ /md5|sha/ }
    end
    let(:build_values) do
      {
        "build.name" => "chef",
        "build.number" => "11.0.6",
      }
    end

    let(:options) { { repository: repository } }

    before do
      allow(subject).to receive(:client).and_return(client)
      allow(subject).to receive(:artifact_for).and_return(artifact)
      allow(subject).to receive(:build_for).and_return(build)
      allow(package).to receive(:metadata).and_return(metadata)
      allow(build).to   receive(:save)
    end

    subject { described_class.new(path, options) }

    describe "#publish" do
      before do
        allow(subject).to receive(:packages).and_return(packages)
        Config.artifactory_base_path("com/getchef")
        Config.publish_retries(1)
      end

      it "validates the package" do
        expect(package).to receive(:validate!).once
        subject.publish
      end

      it "uploads the package" do
        expect(artifact).to receive(:upload).with(
          repository,
          "com/getchef/chef/11.0.6/ubuntu/14.04/chef.deb",
          hash_including(package_properties)
        ).once

        subject.publish
      end

      it "uploads the package's associated *.metadata.json" do
        expect(artifact).to receive(:upload).with(
          repository,
          "com/getchef/chef/11.0.6/ubuntu/14.04/chef.deb.metadata.json",
          hash_including(metadata_json_properites)
        ).once

        subject.publish
      end

      it "it creates a build record for all packages" do
        expect(build).to receive(:save).once
        subject.publish
      end

      context "when no packages exist" do
        let(:packages) { [] }

        it "does nothing" do
          expect(artifact).to_not receive(:upload)
          expect(build).to_not    receive(:save)
        end
      end

      context "when upload fails" do
        before do
          Config.publish_retries(3)

          # This is really ugly but there is no easy way to stub a method to
          # raise an exception a set number of times.
          @times = 0
          allow(artifact).to receive(:upload) do
            @times += 1
            raise Artifactory::Error::HTTPError.new("status" => "409", "message" => "CONFLICT") unless @times > 1
          end
        end

        it "retries the upload " do
          output = capture_logging { subject.publish }
          expect(output).to include("Retrying failed publish")
        end

      end

      context "when a block is given" do
        it "yields the package to the block" do
          block = ->(package) { package.do_something! }
          expect(package).to receive(:do_something!).once
          subject.publish(&block)
        end
      end

      context "when the :build_record option is false" do
        subject { described_class.new(path, repository: repository, build_record: false) }

        it "does not create a build record at the end of publishing" do
          expect(build).to_not receive(:save)
          subject.publish
        end
      end

      context "additional properties are provided" do
        let(:delivery_props) do
          {
            "delivery.change" => "4dbf38de-3e82-439f-8090-c5f3e11aeba6",
            "delivery.sha" => "ec1cb62616350176fc6fd9b1dc4ad3153caa0791",
          }
        end
        let(:options) do
          {
            properties: delivery_props,
            repository: repository,
          }
        end

        it "uploads the package with the provided properties" do
          expect(artifact).to receive(:upload).with(
            repository,
            "com/getchef/chef/11.0.6/ubuntu/14.04/chef.deb",
            hash_including(package_properties.merge(delivery_props))
          ).once

          subject.publish
        end
      end

      context "custom artifactory_publish_pattern is set" do
        before do
          Config.artifactory_publish_pattern("%{platform}/%{platform_version}/%{arch}/%{basename}")
        end

        it "uploads the package to the provided path" do
          expect(artifact).to receive(:upload).with(
            repository,
            "com/getchef/ubuntu/14.04/x86_64/chef.deb",
            hash_including(metadata_json_properites)
          ).once

          subject.publish
        end
      end
    end

    describe "#metadata_properties_for" do
      it "returns the transformed package metadata values" do
        expect(subject.send(:metadata_properties_for, package)).to include(package_properties.merge(build_values))
      end

      context ":build_record is false" do
        let(:options) do
          {
            build_record: false,
            repository: repository,
          }
        end

        it "does not include `build.*` values" do
          expect(subject.send(:metadata_properties_for, package)).to include(package_properties)
          expect(subject.send(:metadata_properties_for, package)).to_not include(build_values)
        end
      end
    end
  end
end
