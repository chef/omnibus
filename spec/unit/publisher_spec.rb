require "spec_helper"

module Omnibus
  # Used in the tests
  class FakePublisher; end

  describe Publisher do
    it { should be_a_kind_of(Logging) }

    describe ".publish" do
      let(:publisher) { double(described_class) }

      before { allow(described_class).to receive(:new).and_return(publisher) }

      it "creates a new instance of the class" do
        expect(described_class).to receive(:new).once
        expect(publisher).to receive(:publish).once
        described_class.publish("/path/to/*.deb")
      end
    end

    let(:pattern) { "/path/to/files/*.deb" }
    let(:options) { { some_option: true } }

    subject { described_class.new(pattern, options) }

    describe '#packages' do
      let(:a) { "/path/to/files/a.deb" }
      let(:b) { "/path/to/files/b.deb" }
      let(:glob) { [a, b] }

      before do
        allow(FileSyncer).to receive(:glob)
          .with(pattern)
          .and_return(glob)
      end

      it "returns an array" do
        expect(subject.packages).to be_an(Array)
      end

      it "returns an array of Package objects" do
        expect(subject.packages.first).to be_a(Package)
      end

      context "a platform mappings matrix is provided" do
        let(:options) do
          {
            platform_mappings: {
              "ubuntu-12.04" => [
                "ubuntu-12.04",
                "ubuntu-14.04",
              ],
            },
          }
        end

        let(:package) do
          Package.new("/path/to/files/chef.deb")
        end

        let(:metadata) do
          Metadata.new(package,
            name: "chef",
            friendly_name: "Chef",
            homepage: "https://www.getchef.com",
            version: "11.0.6",
            iteration: 1,
            basename: "chef.deb",
            license: "Apache-2.0",
            platform: "ubuntu",
            platform_version: "12.04",
            arch: "x86_64",
            sha1: "SHA1",
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
                    git: "https://github.com/opscode/ohai.git",
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
            }
          )
        end

        before do
          allow(package).to receive(:metadata).and_return(metadata)
          allow(FileSyncer).to receive_message_chain(:glob, :map).and_return([package])
        end

        it "creates a package for each publish platform" do
          expect(subject.packages.size).to eq(2)
          expect(
            subject.packages.map do |p|
              p.metadata[:platform_version]
            end
          ).to include("12.04", "14.04")
        end

        context "the build platform does not exist" do
          let(:options) do
            {
              platform_mappings: {
                "ubuntu-10.04" => [
                  "ubuntu-12.04",
                  "ubuntu-14.04",
                ],
              },
            }
          end

          it "prints a warning" do
            output = capture_logging { subject.packages }
            expect(output).to include("Could not locate a package for build platform ubuntu-10.04. Publishing will be skipped for: ubuntu-12.04, ubuntu-14.04")
          end
        end
      end

      context "there are no packages to publish" do
        before do
          allow(FileSyncer).to receive(:glob)
            .with(pattern)
            .and_return([])
        end

        it "prints a warning" do
          output = capture_logging { subject.packages }
          expect(output).to include("No packages found, skipping publish")
        end
      end

    end

    describe '#publish' do
      it "is an abstract method" do
        expect { subject.publish }.to raise_error(NotImplementedError)
      end
    end
  end
end
