require "spec_helper"

module Omnibus
  describe Packager::DEB do
    let(:project) do
      Project.new.tap do |project|
        project.name("project")
        project.homepage("https://example.com")
        project.install_dir("/opt/project")
        project.build_version("1.2.3")
        project.build_iteration("2")
        project.maintainer("Chef Software")
        project.provide("chefy-package")
        project.license(project_license) if project_license
      end
    end

    subject { described_class.new(project) }

    let(:project_license) { nil }
    let(:project_root) { File.join(tmp_path, "project/root") }
    let(:package_dir)  { File.join(tmp_path, "package/dir") }
    let(:staging_dir)  { File.join(tmp_path, "staging/dir") }

    before do
      Config.project_root(project_root)
      Config.package_dir(package_dir)

      allow(subject).to receive(:staging_dir).and_return(staging_dir)
      create_directory(staging_dir)
      create_directory("#{staging_dir}/DEBIAN")
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

    describe "#section" do
      it "is a DSL method" do
        expect(subject).to have_exposed_method(:section)
      end

      it "has a default value" do
        expect(subject.section).to eq("misc")
      end

      it "must be a string" do
        expect { subject.section(Object.new) }.to raise_error(InvalidValue)
      end
    end

    describe "#id" do
      it "is :deb" do
        expect(subject.id).to eq(:deb)
      end
    end

    describe "#package_name" do
      before do
        allow(subject).to receive(:safe_architecture).and_return("amd64")
      end

      it "includes the name, version, and build iteration" do
        expect(subject.package_name).to eq("project_1.2.3-2_amd64.deb")
      end
    end

    describe "#debian_dir" do
      it "is nested inside the staging_dir" do
        expect(subject.debian_dir).to eq("#{staging_dir}/DEBIAN")
      end
    end

    describe "#write_control_file" do
      before do
        allow(subject).to receive(:safe_architecture).and_return("amd64")
      end

      it "generates the file" do
        subject.write_control_file
        expect("#{staging_dir}/DEBIAN/control").to be_a_file
      end

      it "has the correct content" do
        subject.write_control_file
        contents = File.read("#{staging_dir}/DEBIAN/control")

        expect(contents).to include("Package: project")
        expect(contents).to include("Version: 1.2.3")
        expect(contents).to include("License: Unspecified")
        expect(contents).to include("Vendor: Omnibus <omnibus@getchef.com>")
        expect(contents).to include("Architecture: amd64")
        expect(contents).to include("Maintainer: Chef Software")
        expect(contents).to include("Provides: chefy-package")
        expect(contents).to include("Installed-Size: 0")
        expect(contents).to include("Section: misc")
        expect(contents).to include("Priority: extra")
        expect(contents).to include("Homepage: https://example.com")
        expect(contents).to include("Description: The full stack of project")
      end
    end

    describe "#write_conffiles_file" do
      before do
        project.config_file("/opt/project/file1")
        project.config_file("/opt/project/file2")
      end

      context "when there are no files" do
        before { project.config_files.clear }

        it "does not render the file" do
          subject.write_conffiles_file
          expect("#{staging_dir}/DEBIAN/conffiles").to_not be_a_file
        end
      end

      it "generates the file" do
        subject.write_conffiles_file
        expect("#{staging_dir}/DEBIAN/conffiles").to be_a_file
      end

      it "has the correct content" do
        subject.write_conffiles_file
        contents = File.read("#{staging_dir}/DEBIAN/conffiles")

        expect(contents).to include("/opt/project/file1")
        expect(contents).to include("/opt/project/file2")
      end
    end

    describe "#write_scripts" do
      before do
        create_file("#{project_root}/package-scripts/project/preinst") { "preinst" }
        create_file("#{project_root}/package-scripts/project/postinst") { "postinst" }
        create_file("#{project_root}/package-scripts/project/prerm") { "prerm" }
        create_file("#{project_root}/package-scripts/project/postrm") { "postrm" }
      end

      it "copies the scripts into the DEBIAN dir with permissions = 100755", :not_supported_on_windows do
        subject.write_scripts

        expect("#{staging_dir}/DEBIAN/preinst").to be_a_file
        expect("#{staging_dir}/DEBIAN/postinst").to be_a_file
        expect("#{staging_dir}/DEBIAN/prerm").to be_a_file
        expect("#{staging_dir}/DEBIAN/postrm").to be_a_file

        expect("#{staging_dir}/DEBIAN/preinst").to have_permissions "100755"
        expect("#{staging_dir}/DEBIAN/postinst").to have_permissions "100755"
        expect("#{staging_dir}/DEBIAN/prerm").to have_permissions "100755"
        expect("#{staging_dir}/DEBIAN/postrm").to have_permissions "100755"
      end

      it "logs a message" do
        output = capture_logging do
          subject.write_scripts
        end

        expect(output).to include("Adding script `preinst'")
        expect(output).to include("Adding script `postinst'")
        expect(output).to include("Adding script `prerm'")
        expect(output).to include("Adding script `postrm'")
      end
    end

    describe "#write_md5_sums" do
      before do
        create_file("#{staging_dir}/.filea") { ".filea" }
        create_file("#{staging_dir}/file1") { "file1" }
        create_file("#{staging_dir}/file2") { "file2" }
        create_file("#{staging_dir}/DEBIAN/preinst") { "preinst" }
        create_file("#{staging_dir}/DEBIAN/postrm") { "postrm" }
      end

      it "generates the file" do
        subject.write_md5_sums
        expect("#{staging_dir}/DEBIAN/md5sums").to be_a_file
      end

      it "has the correct content" do
        subject.write_md5_sums
        contents = File.read("#{staging_dir}/DEBIAN/md5sums")

        expect(contents).to include("9334770d184092f998009806af702c8c  .filea")
        expect(contents).to include("826e8142e6baabe8af779f5f490cf5f5  file1")
        expect(contents).to include("1c1c96fd2cf8330db0bfa936ce82f3b9  file2")
        expect(contents).to_not include("1c1c96fd2cf8330db0bfa936ce82f3b9 file2")
        expect(contents).to_not include("DEBIAN/preinst")
        expect(contents).to_not include("DEBIAN/postrm")
      end
    end

    describe "#create_deb_file" do
      before do
        allow(subject).to receive(:shellout!)
        allow(Dir).to receive(:chdir) { |_, &b| b.call }
        allow(subject).to receive(:safe_architecture).and_return("amd64")
      end

      it "logs a message" do
        output = capture_logging { subject.create_deb_file }
        expect(output).to include("Creating .deb file")
      end

      it "executes the command using `fakeroot`" do
        expect(subject).to receive(:shellout!)
          .with(/\Afakeroot/)
        subject.create_deb_file
      end

      it "uses the correct command" do
        expect(subject).to receive(:shellout!)
          .with(/dpkg-deb -z9 -Zgzip -D --build/)
        subject.create_deb_file
      end
    end

    describe "#package_size" do
      before do
        project.install_dir(staging_dir)

        create_file("#{staging_dir}/file1") { "1" * 10_000 }
        create_file("#{staging_dir}/file2") { "2" * 20_000 }
      end

      it "stats all the files in the install_dir" do
        expect(subject.package_size).to eq(29)
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

          expect(output).to include("The `name' component of Debian package names can only include")
        end
      end
    end

    describe "#safe_build_iteration" do
      it "returns the build iteration" do
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

          expect(output).to include("Dashes hold special significance in the Debian package versions.")
        end
      end

      context "when the project build_version has invalid characters" do
        before { project.build_version("1.2$alpha.~##__2") }

        it "returns the value while logging a message" do
          output = capture_logging do
            expect(subject.safe_version).to eq("1.2_alpha.~_2")
          end

          expect(output).to include("The `version' component of Debian package names can only include")
        end
      end
    end

    describe "#safe_architecture" do
      let(:shellout) { double("Mixlib::ShellOut", :run_command => true, :error! => nil) }

      before do
        allow(Mixlib::ShellOut).to receive(:new).and_return(shellout)
      end

      it "shells out to dpkg and returns the output" do
        allow(shellout).to receive(:stdout).and_return("test_arch\n")
        expect(subject.safe_architecture).to eq("test_arch")
      end

      it "returns noarch if no architecture is returned by dpkg" do
        allow(shellout).to receive(:stdout).and_return("")
        expect(subject.safe_architecture).to eq("noarch")
      end
    end
  end
end
