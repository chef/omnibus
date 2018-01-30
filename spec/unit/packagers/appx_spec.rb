require "spec_helper"

module Omnibus
  describe Packager::APPX do
    let(:project) do
      Project.new.tap do |project|
        project.name("project")
        project.homepage("https://example.com")
        project.install_dir(install_dir)
        project.build_version("1.2.3")
        project.build_iteration("2")
        project.maintainer("Chef Software <maintainers@chef.io>")
      end
    end

    subject { described_class.new(project) }

    let(:project_root) { File.join(tmp_path, "project/root") }
    let(:package_dir)  { File.join(tmp_path, "package/dir") }
    let(:staging_dir)  { File.join(tmp_path, "staging/dir") }
    let(:install_dir)  { File.join(tmp_path, "install/dir") }

    before do
      Config.project_root(project_root)
      Config.package_dir(package_dir)

      allow(subject).to receive(:staging_dir).and_return(staging_dir)
      create_directory(install_dir)
    end

    describe "DSL" do
      it "exposes :signing_identity" do
        expect(subject).to have_exposed_method(:signing_identity)
      end
    end

    describe "#id" do
      it "is :pkg" do
        expect(subject.id).to eq(:appx)
      end
    end

    describe "#package_name" do
      before do
        allow(Config).to receive(:windows_arch).and_return(:foo_arch)
      end

      it "includes the name, version, and build iteration" do
        expect(subject.package_name).to eq("project-1.2.3-2-foo_arch.appx")
      end
    end

    describe "#write_manifest_file" do
      before do
        allow(subject).to receive(:shellout!).and_return(double("output", stdout: 'CN="Chef", O="Chef"'))
        allow(subject).to receive(:signing_identity).and_return({})
      end

      it "generates the file" do
        subject.write_manifest_file
        expect("#{install_dir}/AppxManifest.xml").to be_a_file
      end

      it "has the correct content" do
        subject.write_manifest_file
        contents = File.read("#{install_dir}/AppxManifest.xml")

        expect(contents).to include('Name="project"')
        expect(contents).to include('Version="1.2.3.2"')
        expect(contents).to include('Publisher="CN=&quot;Chef&quot;, O=&quot;Chef&quot;"')
        expect(contents).to include("<DisplayName>Project</DisplayName>")
        expect(contents).to include(
          '<PublisherDisplayName>"Chef Software &lt;maintainers@chef.io&gt;"</PublisherDisplayName>'
        )
      end
    end

    describe "#windows_package_version" do
      context "when the project build_version semver" do
        it "returns the right value" do
          expect(subject.windows_package_version).to eq("1.2.3.2")
        end
      end

      context "when the project build_version is git" do
        before { project.build_version("1.2.3-alpha.1+20140501194641.git.94.561b564") }

        it "returns the right value" do
          expect(subject.windows_package_version).to eq("1.2.3.2")
        end
      end
    end

    describe "#pack_command" do
      it "returns a String" do
        expect(subject.pack_command("foo")).to be_a(String)
      end

      it "packages install directory" do
        expect(subject.pack_command("foo")).to(
          include("/d \"#{subject.windows_safe_path(install_dir)}\"")
        )
      end

      it "writes to the given appx file" do
        expect(subject.pack_command("foo")).to include("/p foo")
      end
    end

    context "when signing parameters are provided" do
      let(:appx) { "someappx.appx" }

      context "when invalid parameters" do
        it "should raise an InvalidValue error when the certificate name is not a String" do
          expect { subject.signing_identity(Object.new) }.to raise_error(InvalidValue)
        end

        it "should raise an InvalidValue error when params is not a Hash" do
          expect { subject.signing_identity("foo", Object.new) }.to raise_error(InvalidValue)
        end

        it "should raise an InvalidValue error when params contains an invalid key" do
          expect { subject.signing_identity("foo", bar: "baz") }.to raise_error(InvalidValue)
        end
      end

      context "when valid parameters" do
        before do
          allow(subject).to receive(:shellout!)
        end

        describe "#timestamp_servers" do
          it "defaults to using ['http://timestamp.digicert.com','http://timestamp.verisign.com/scripts/timestamp.dll']" do
            subject.signing_identity("foo")
            expect(subject).to receive(:try_sign).with(appx, "http://timestamp.digicert.com").and_return(false)
            expect(subject).to receive(:try_sign).with(appx, "http://timestamp.verisign.com/scripts/timestamp.dll").and_return(true)
            subject.sign_package(appx)
          end

          it "uses the timestamp server if provided through the #timestamp_server dsl" do
            subject.signing_identity("foo", timestamp_servers: "http://fooserver")
            expect(subject).to receive(:try_sign).with(appx, "http://fooserver").and_return(true)
            subject.sign_package(appx)
          end

          it "tries all timestamp server if provided through the #timestamp_server dsl" do
            subject.signing_identity("foo", timestamp_servers: ["http://fooserver", "http://barserver"])
            expect(subject).to receive(:try_sign).with(appx, "http://fooserver").and_return(false)
            expect(subject).to receive(:try_sign).with(appx, "http://barserver").and_return(true)
            subject.sign_package(appx)
          end

          it "tries all timestamp server if provided through the #timestamp_servers dsl and stops at the first available" do
            subject.signing_identity("foo", timestamp_servers: ["http://fooserver", "http://barserver"])
            expect(subject).to receive(:try_sign).with(appx, "http://fooserver").and_return(true)
            expect(subject).not_to receive(:try_sign).with(appx, "http://barserver")
            subject.sign_package(appx)
          end

          it "raises an exception if there are no available timestamp servers" do
            subject.signing_identity("foo", timestamp_servers: "http://fooserver")
            expect(subject).to receive(:try_sign).with(appx, "http://fooserver").and_return(false)
            expect { subject.sign_package(appx) }.to raise_error(FailedToSignWindowsPackage)
          end
        end
      end
    end
  end
end
