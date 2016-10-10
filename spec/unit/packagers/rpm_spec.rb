require "spec_helper"

module Omnibus
  describe Packager::RPM do
    let(:project) do
      Project.new.tap do |project|
        project.name("project")
        project.homepage("https://example.com")
        project.install_dir("/opt/project")
        project.build_version("1.2.3")
        project.build_iteration("2")
        project.maintainer("Chef Software")
        project.replace("old-project")
        project.provide("chefy-package")
        project.license(project_license) if project_license
      end
    end

    subject { described_class.new(project) }

    let(:project_license) { nil }
    let(:project_root) { File.join(tmp_path, "project/root") }
    let(:package_dir)  { File.join(tmp_path, "package/dir") }
    let(:staging_dir)  { File.join(tmp_path, "staging/dir") }
    let(:architecture) { "x86_64" }

    before do
      Config.project_root(project_root)
      Config.package_dir(package_dir)

      allow(subject).to receive(:staging_dir).and_return(staging_dir)
      create_directory(staging_dir)
      create_directory("#{staging_dir}/BUILD")
      create_directory("#{staging_dir}/RPMS")
      create_directory("#{staging_dir}/SRPMS")
      create_directory("#{staging_dir}/SOURCES")
      create_directory("#{staging_dir}/SPECS")

      stub_ohai(platform: "redhat", version: "6.5") do |data|
        data["kernel"]["machine"] = architecture
      end
    end

    describe "#signing_passphrase" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:signing_passphrase)
      end

      it "has a no default value" do
        expect(subject.signing_passphrase).to be(nil)
      end
    end

    describe "#vendor" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:vendor)
      end

      it "has a default value" do
        expect(subject.vendor).to eq("Omnibus <omnibus@getchef.com>")
      end

      it "must be a string" do
        expect { subject.vendor(Object.new) }.to raise_error(InvalidValue)
      end
    end

    describe "#license" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:license)
      end

      it "has a default value" do
        expect(subject.license).to eq("Unspecified")
      end

      it "must be a string" do
        expect { subject.license(Object.new) }.to raise_error(InvalidValue)
      end

      context "with project license" do
        let(:project_license) { "custom-license" }

        it "uses project license" do
          expect(subject.license).to eq("custom-license")
        end
      end
    end

    describe "#priority" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:priority)
      end

      it "has a default value" do
        expect(subject.priority).to eq("extra")
      end

      it "must be a string" do
        expect { subject.priority(Object.new) }.to raise_error(InvalidValue)
      end
    end

    describe "#category" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:category)
      end

      it "has a default value" do
        expect(subject.category).to eq("default")
      end

      it "must be a string" do
        expect { subject.category(Object.new) }.to raise_error(InvalidValue)
      end
    end

    describe "#dist_tag" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:dist_tag)
      end

      it "has a default value" do
        expect(subject.dist_tag).to eq(".el6")
      end
    end

    describe "#id" do
      it "is :rpm" do
        expect(subject.id).to eq(:rpm)
      end
    end

    describe "#package_name" do
      context "when dist_tag is enabled" do
        before do
          allow(subject).to receive(:safe_architecture).and_return("x86_64")
        end

        it "includes the name, version, and build iteration" do
          expect(subject.package_name).to eq("project-1.2.3-2.el6.x86_64.rpm")
        end
      end

      context "when dist_tag is disabled" do
        before do
          allow(subject).to receive(:dist_tag).and_return(false)
        end

        it "excludes dist tag" do
          expect(subject.package_name).to eq("project-1.2.3-2.x86_64.rpm")
        end
      end
    end

    describe "#build_dir" do
      it "is nested inside the staging_dir" do
        expect(subject.build_dir).to eq("#{staging_dir}/BUILD")
      end
    end

    describe "#write_rpm_spec" do
      before do
        allow(subject).to receive(:safe_architecture).and_return("x86_64")
      end

      let(:spec_file) { "#{staging_dir}/SPECS/project-1.2.3-2.el6.x86_64.rpm.spec" }

      it "generates the file" do
        subject.write_rpm_spec
        expect(spec_file).to be_a_file
      end

      it "has the correct content" do
        subject.write_rpm_spec
        contents = File.read(spec_file)

        expect(contents).to include("Name: project")
        expect(contents).to include("Version: 1.2.3")
        expect(contents).to include("Release: 2.el6")
        expect(contents).to include("Summary:  The full stack of project")
        expect(contents).to include("AutoReqProv: no")
        expect(contents).to include("BuildRoot: %buildroot")
        expect(contents).to include("Prefix: /")
        expect(contents).to include("Group: default")
        expect(contents).to include("License: Unspecified")
        expect(contents).to include("Vendor: Omnibus <omnibus@getchef.com>")
        expect(contents).to include("URL: https://example.com")
        expect(contents).to include("Packager: Chef Software")
        expect(contents).to include("Obsoletes: old-project")
      end

      context "when scripts are given" do
        let(:scripts) { %w{ pre post preun postun verifyscript pretans posttrans } }

        before do
          scripts.each do |script_name|
            create_file("#{project_root}/package-scripts/project/#{script_name}") do
              "Contents of #{script_name}"
            end
          end
        end

        it "writes the scripts into the spec" do
          subject.write_rpm_spec
          contents = File.read(spec_file)

          scripts.each do |script_name|
            expect(contents).to include("%#{script_name}")
            expect(contents).to include("Contents of #{script_name}")
          end
        end
      end

      context "when scripts with default omnibus naming are given" do
        let(:default_scripts) {  %w{ preinst postinst prerm postrm } }

        before do
          default_scripts.each do |default_name|
            create_file("#{project_root}/package-scripts/project/#{default_name}") do
              "Contents of #{default_name}"
            end
          end
        end

        it "writes the scripts into the spec" do
          subject.write_rpm_spec
          contents = File.read(spec_file)

          default_scripts.each do |script_name|
            mapped_name = Packager::RPM::SCRIPT_MAP[script_name.to_sym]
            expect(contents).to include("%#{mapped_name}")
            expect(contents).to include("Contents of #{script_name}")
          end
        end
      end

      context "when files and directories are present" do
        before do
          create_file("#{staging_dir}/BUILD/.file1")
          create_file("#{staging_dir}/BUILD/file2")
          create_directory("#{staging_dir}/BUILD/.dir1")
          create_directory("#{staging_dir}/BUILD/dir2")
          create_directory("#{staging_dir}/BUILD/dir3 space")
        end

        it "writes them into the spec" do
          subject.write_rpm_spec
          contents = File.read(spec_file)

          expect(contents).to include("%dir /.dir1")
          expect(contents).to include("/.file1")
          expect(contents).to include("%dir /dir2")
          expect(contents).to include("/file2")
          expect(contents).to include("%dir \"/dir3 space\"")
        end
      end

      context "when leaf directories owned by the filesystem package are present" do
        before do
          create_directory("#{staging_dir}/BUILD/usr/lib")
          create_directory("#{staging_dir}/BUILD/opt")
          create_file("#{staging_dir}/BUILD/opt/thing")
        end

        it "is written into the spec with ownership and permissions" do
          subject.write_rpm_spec
          contents = File.read(spec_file)

          expect(contents).to include("%dir %attr(0755,root,root) /opt")
          expect(contents).to include("%dir %attr(0555,root,root) /usr/lib")
        end
      end

      context "when the platform_family is wrlinux" do
        let(:spec_file) { "#{staging_dir}/SPECS/project-1.2.3-2.nexus5.x86_64.rpm.spec" }

        before do
          stub_ohai(platform: "nexus", version: "5")
        end

        it "writes out a spec file with no BuildArch" do
          subject.write_rpm_spec
          contents = File.read(spec_file)

          expect(contents).not_to include("BuildArch")
        end
      end

      context "when dist_tag is disabled" do
        let(:spec_file) { "#{staging_dir}/SPECS/project-1.2.3-2.x86_64.rpm.spec" }

        before do
          allow(subject).to receive(:dist_tag).and_return(false)
        end

        it "has the correct release" do
          subject.write_rpm_spec
          contents = File.read(spec_file)
          expect(contents).to include("Release: 2")
        end
      end
    end

    describe "#create_rpm_file" do
      before do
        allow(subject).to receive(:shellout!)
        allow(Dir).to receive(:chdir) { |_, &b| b.call }
      end

      it "logs a message" do
        output = capture_logging { subject.create_rpm_file }
        expect(output).to include("Creating .rpm file")
      end

      it "uses the correct command" do
        expect(subject).to receive(:shellout!)
          .with(/rpmbuild --target #{architecture} -bb --buildroot/)
        subject.create_rpm_file
      end

      context "when RPM signing is enabled" do
        before do
          subject.signing_passphrase("foobar")
          allow(Dir).to receive(:mktmpdir).and_return(tmp_path)
        end

        it "signs the rpm" do
          expect(subject).to receive(:shellout!)
            .with(/sign\-rpm/, kind_of(Hash))
          subject.create_rpm_file
        end
      end
    end

    describe "#spec_file" do
      before do
        allow(subject).to receive(:package_name).and_return("package_name")
      end

      it "includes the package_name" do
        expect(subject.spec_file).to eq("#{staging_dir}/SPECS/package_name.spec")
      end
    end

    describe "#rpm_safe" do
      it "adds quotes when required" do
        expect(subject.rpm_safe("file path")).to eq('"file path"')
      end

      it "escapes [" do
        expect(subject.rpm_safe("[foo")).to eq('[\\[]foo')
      end

      it "escapes *" do
        expect(subject.rpm_safe("*foo")).to eq("[*]foo")
      end

      it "escapes ?" do
        expect(subject.rpm_safe("?foo")).to eq("[?]foo")
      end

      it "escapes %" do
        expect(subject.rpm_safe("%foo")).to eq("[%]foo")
      end
    end

    describe "#safe_base_package_name" do
      context 'when the project name is "safe"' do
        it "returns the value without logging a message" do
          expect(subject.safe_base_package_name).to eq("project")
          expect(subject).to_not receive(:log)
        end
      end

      context "when the project name has invalid characters" do
        before { project.name("Pro$ject123.for-realz_2") }

        it "returns the value while logging a message" do
          output = capture_logging do
            expect(subject.safe_base_package_name).to eq("pro-ject123.for-realz-2")
          end

          expect(output).to include("The `name' component of RPM package names can only include")
        end
      end
    end

    describe "#safe_build_iteration" do
      it "returns the build iternation" do
        expect(subject.safe_build_iteration).to eq(project.build_iteration)
      end
    end

    describe "#safe_version" do
      context 'when the project build_version is "safe"' do
        it "returns the value without logging a message" do
          expect(subject.safe_version).to eq("1.2.3")
          expect(subject).to_not receive(:log)
        end
      end

      context "when the project build_version has dashes" do
        before { project.build_version("1.2-rc.1") }

        it "returns the value while logging a message" do
          output = capture_logging do
            expect(subject.safe_version).to eq("1.2~rc.1")
          end

          expect(output).to include("Tildes hold special significance in the RPM package versions.")
        end
      end

      context "when the project build_version has invalid characters" do
        before { project.build_version("1.2-pre_alpha.##__2") }

        it "returns the value while logging a message" do
          output = capture_logging do
            expect(subject.safe_version).to eq("1.2~pre_alpha._2")
          end

          expect(output).to include("The `version' component of RPM package names can only include")
        end
      end

      context "when the build is for nexus" do
        before do
          project.build_version("1.2-3")
          stub_ohai(platform: "nexus", version: "5")
        end

        it "returns the value while logging a message" do
          output = capture_logging do
            expect(subject.safe_version).to eq("1.2_3")
          end

          expect(output).to include("rpmbuild on Wind River Linux does not support this")
        end
      end

      context "when the build is for ios_xr" do
        before do
          project.build_version("1.2-3")
          stub_ohai(platform: "ios_xr", version: "6.0.0.14I")
        end

        it "returns the value while logging a message" do
          output = capture_logging do
            expect(subject.safe_version).to eq("1.2_3")
          end

          expect(output).to include("rpmbuild on Wind River Linux does not support this")
        end
      end
    end

    describe "#safe_architecture" do
      before do
        stub_ohai(platform: "redhat", version: "6.5") do |data|
          data["kernel"]["machine"] = "i386"
        end
      end

      it "returns the value from Ohai" do
        expect(subject.safe_architecture).to eq("i386")
      end

      context "when i686" do
        before do
          stub_ohai(platform: "redhat", version: "6.5") do |data|
            data["kernel"]["machine"] = "i686"
          end
        end

        it "returns i386" do
          expect(subject.safe_architecture).to eq("i386")
        end
      end

      context "on Pidora" do
        before do
          # There's no Pidora in Fauxhai :(
          stub_ohai(platform: "fedora", version: "20") do |data|
            data["platform"] = "pidora"
            data["platform_version"] = "20"
            data["kernel"]["machine"] = "armv6l"
          end
        end

        it "returns armv6hl" do
          expect(subject.safe_architecture).to eq("armv6hl")
        end
      end
    end
  end
end
