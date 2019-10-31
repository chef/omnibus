require "spec_helper"

module Omnibus
  describe Metadata do
    let(:instance) do
      double(described_class, path: "/path/to/package.deb.metadata.json")
    end

    let(:package_path) { "/path/to/package.deb" }
    let(:license_path) { "/opt/project/LICENSE" }

    let(:package) do
      double(Package,
        name:   "package",
        path:   package_path,
        md5:    "abc123",
        sha1:   "abc123",
        sha256: "abcd1234",
        sha512: "abcdef123456")
    end

    let(:project) do
      double(Project,
        name:             "some-project",
        friendly_name:    "Some Project",
        homepage:         "https://some.project.io",
        build_version:    "1.2.3",
        build_iteration:  "1",
        license:          "Apache-2.0",
        built_manifest:    double(Manifest,
          to_hash: {
            manifest_format: 2,
            build_version: "1.2.3",
            build_git_revision: "SHA",
            license: "Apache-2.0",
          }),
        license_file_path: license_path)
    end

    let(:data) { { foo: "bar" } }
    let(:license_file_content) do
      <<~EOH
        some_project 1.2.3 license: "Apache-2.0"

                                      Apache License
                                Version 2.0, January 2004
                             http://www.apache.org/licenses/
        TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

        1. Definitions.

           "License" shall mean the terms and conditions for use, reproduction,
           and distribution as defined by Sections 1 through 9 of this document.

        ...
      EOH
    end

    subject { described_class.new(package, data) }

    describe ".generate" do
      let(:metadata_json_content) { StringIO.new }
      let(:package_path) { "/path/to/package.deb" }

      before do
        allow(File).to receive(:exist?).with(package_path).and_return(true)
        allow(Package).to receive(:new).with(package_path).and_return(package)
        allow(File).to receive(:exist?).with(license_path).and_return(true)
        allow(File).to receive(:read).with(license_path).and_return(license_file_content)
        # mock out `Metadata#save`
        allow(File).to receive(:open).with("#{package_path}.metadata.json", "w+").and_yield(metadata_json_content)
      end

      it "creates a *.metadata.json file with the correct content" do

        described_class.generate(package_path, project)

        expect(metadata_json_content.string).to include_json(
          basename: "package",
          md5:      "abc123",
          sha1:     "abc123",
          sha256:   "abcd1234",
          sha512:   "abcdef123456",
          platform: "ubuntu",
          platform_version: "16.04",
          arch: "x86_64",
          name: "some-project",
          friendly_name: "Some Project",
          homepage: "https://some.project.io",
          version: "1.2.3",
          iteration: "1",
          version_manifest: {
            manifest_format: 2,
            build_version: "1.2.3",
            build_git_revision: "SHA",
            license: "Apache-2.0",
          },
          license_content: license_file_content
        )
      end

      context "the package file does not exist" do
        before do
          allow(File).to receive(:exist?).with(package_path).and_return(false)
        end

        it "raises an exception" do
          expect { described_class.generate(package_path, project) }.to raise_error(Omnibus::NoPackageFile)
        end
      end

      context "the license file does not exist" do
        before do
          allow(File).to receive(:exist?).with(license_path).and_return(false)
        end

        it "does not include the license content" do
          described_class.generate(package_path, project)
          expect(metadata_json_content.string).to include_json(
            license_content: ""
          )
        end
      end
    end

    describe ".arch" do
      let(:architecture) { "x86_64" }

      before do
        stub_ohai(platform: "ubuntu", version: "16.04") do |data|
          data["kernel"]["machine"] = architecture
        end
      end

      it "returns the architecture" do
        expect(described_class.arch).to eq("x86_64")
      end

      context "on solaris" do
        before do
          stub_ohai(platform: "solaris2", version: "5.11") do |data|
            data["platform"] = "solaris2"
            data["kernel"]["machine"] = architecture
          end
        end

        context "architecture is Intel-based" do
          let(:architecture) { "i86pc" }

          it "returns i386" do
            expect(described_class.arch).to eq("i386")
          end
        end

        context "architecture is SPARC-based" do
          let(:architecture) { "sun4v" }

          it "returns sparc" do
            expect(described_class.arch).to eq("sparc")
          end
        end
      end

      context "on windows" do
        before do
          stub_ohai(platform: "windows", version: "2012R2") do |data|
            data["kernel"]["machine"] = architecture
          end
        end

        it "returns a 32-bit value based on Config.windows_arch being set to x86" do
          expect(Config).to receive(:windows_arch).and_return(:x86)
          expect(described_class.arch).to eq("i386")
        end
      end
    end

    describe ".platform_shortname" do
      it "returns el on rhel" do
        stub_ohai(platform: "redhat", version: "6.9")
        expect(described_class.platform_shortname).to eq("el")
      end

      it "returns sles on suse" do
        stub_ohai(platform: "suse", version: "12.2")
        expect(described_class.platform_shortname).to eq("sles")
      end

      it "returns .platform on all other systems" do
        stub_ohai(platform: "ubuntu", version: "16.04")
        expect(described_class.platform_shortname).to eq("ubuntu")
      end
    end

    describe ".platform_version" do
      shared_examples "a version manipulator" do |platform_shortname, version, expected|
        context "on #{platform_shortname}-#{version}" do
          it "returns the correct value" do
            stub_ohai(platform: "ubuntu", version: "16.04") do |data|
              data["platform"] = platform_shortname
              data["platform_version"] = version
            end

            expect(described_class.platform_version).to eq(expected)
          end
        end
      end

      it_behaves_like "a version manipulator", "aix", "7.1", "7.1"
      it_behaves_like "a version manipulator", "amazon", "2018.03", "2018.03"
      it_behaves_like "a version manipulator", "arch", "rolling", "rolling"
      it_behaves_like "a version manipulator", "centos", "5.9.6", "5"
      it_behaves_like "a version manipulator", "debian", "7.1", "7"
      it_behaves_like "a version manipulator", "debian", "6.9", "6"
      it_behaves_like "a version manipulator", "el", "6.5", "6"
      it_behaves_like "a version manipulator", "fedora", "11.5", "11"
      it_behaves_like "a version manipulator", "freebsd", "10.0", "10"
      it_behaves_like "a version manipulator", "gentoo", "4.9.95-gentoo", "rolling"
      it_behaves_like "a version manipulator", "kali", "rolling", "rolling"
      it_behaves_like "a version manipulator", "mac_os_x", "10.9.1", "10.9"
      it_behaves_like "a version manipulator", "omnios", "r151010", "r151010"
      it_behaves_like "a version manipulator", "openbsd", "5.4.4", "5.4"
      it_behaves_like "a version manipulator", "opensuseleap", "42.3", "42.3"
      it_behaves_like "a version manipulator", "opensuse", "5.9", "5.9"
      it_behaves_like "a version manipulator", "pidora", "11.5", "11"
      it_behaves_like "a version manipulator", "raspbian", "7.1", "7"
      it_behaves_like "a version manipulator", "rhel", "6.5", "6"
      it_behaves_like "a version manipulator", "slackware", "12.0.1", "12.0"
      it_behaves_like "a version manipulator", "sles", "11.2", "11"
      it_behaves_like "a version manipulator", "suse", "12.0", "12"
      it_behaves_like "a version manipulator", "smartos", "20120809T221258Z", "20120809T221258Z"
      it_behaves_like "a version manipulator", "solaris2", "5.9", "5.9"
      it_behaves_like "a version manipulator", "ubuntu", "10.04", "10.04"
      it_behaves_like "a version manipulator", "ubuntu", "10.04.04", "10.04"
      it_behaves_like "a version manipulator", "windows", "5.0.2195", "2000"
      it_behaves_like "a version manipulator", "windows", "5.1.2600", "xp"
      it_behaves_like "a version manipulator", "windows", "5.2.3790", "2003r2"
      it_behaves_like "a version manipulator", "windows", "6.0.6001", "2008"
      it_behaves_like "a version manipulator", "windows", "6.1.7600", "7"
      it_behaves_like "a version manipulator", "windows", "6.1.7601", "2008r2"
      it_behaves_like "a version manipulator", "windows", "6.2.9200", "2012"
      it_behaves_like "a version manipulator", "windows", "6.3.9200", "2012r2"
      it_behaves_like "a version manipulator", "windows", "6.3.9600", "2012r2"
      it_behaves_like "a version manipulator", "windows", "10.0.10240", "10"

      context "given an unknown platform" do
        before do
          stub_ohai(platform: "ubuntu", version: "16.04") do |data|
            data["platform"] = "bacon"
            data["platform_version"] = "1.crispy"
          end
        end

        it "raises an exception" do
          expect { described_class.platform_version }
            .to raise_error(UnknownPlatform)
        end
      end

      context "given an unknown windows platform version" do
        before do
          stub_ohai(platform: "ubuntu", version: "16.04") do |data|
            data["platform"] = "windows"
            data["platform_version"] = "1.2.3"
          end
        end

        it "raises an exception" do
          expect { described_class.platform_version }
            .to raise_error(UnknownPlatformVersion)
        end
      end
    end

    describe ".for_package" do
      it "raises an exception when the file does not exist" do
        allow(File).to receive(:read).and_raise(Errno::ENOENT)
        expect { described_class.for_package(package) }
          .to raise_error(NoPackageMetadataFile)
      end

      it "returns a metadata object" do
        allow(File).to receive(:read).and_return('{ "platform": "ubuntu" }')
        expect(described_class.for_package(package)).to be_a(described_class)
      end

      it "loads the metadata from disk" do
        allow(File).to receive(:read).and_return('{ "platform": "ubuntu" }')
        instance = described_class.for_package(package)

        expect(instance[:platform]).to eq("ubuntu")
      end

      it "correctly truncates sles platform versions" do
        allow(File).to receive(:read).and_return('{ "platform": "sles", "platform_version": "11.2" }')
        instance = described_class.for_package(package)

        expect(instance[:platform_version]).to eq("11")
      end

      it "ensures an iteration exists" do
        allow(File).to receive(:read).and_return("{}")
        instance = described_class.for_package(package)

        expect(instance[:iteration]).to eq(1)
      end

      it "does not change existing iterations" do
        allow(File).to receive(:read).and_return('{ "iteration": 4 }')
        instance = described_class.for_package(package)

        expect(instance[:iteration]).to eq(4)
      end
    end

    describe ".path_for" do
      it "returns the postfixed .metadata.json" do
        expect(described_class.path_for(package))
          .to eq("/path/to/package.deb.metadata.json")
      end
    end

    describe "#name" do
      it "returns the basename of the package" do
        expect(subject.name).to eq("package.deb.metadata.json")
      end
    end

    describe "#path" do
      it "delegates to .path_for" do
        expect(described_class).to receive(:path_for).once
        subject.path
      end
    end

    describe "#save" do
      let(:file) { double(File) }

      before { allow(File).to receive(:open).and_yield(file) }

      it "saves the file to disk" do
        expect(file).to receive(:write).once
        subject.save
      end
    end

    describe "#to_json" do
      it "generates pretty JSON" do
        expect(subject.to_json.strip).to eq <<-EOH.gsub(/^ {10}/, "").strip
          {
            "foo": "bar"
          }
        EOH
      end
    end
  end
end
