require "spec_helper"

module Omnibus
  describe Packager::PKGSRC do
    let(:project) do
      Project.new.tap do |project|
        project.name("project")
        project.homepage("https://example.com")
        project.install_dir("/opt/project")
        project.build_version("1.2.3")
        project.build_iteration("1")
        project.maintainer("Chef Software")
      end
    end

    subject { described_class.new(project) }

    let(:project_root) { File.join(tmp_path, "project/root") }
    let(:package_dir)  { File.join(tmp_path, "package/dir") }
    let(:staging_dir)  { File.join(tmp_path, "staging/dir") }
    let(:architecture) { "86_64" }

    before do
      # This is here to allow this unit test to run on windows.
      allow(File).to receive(:expand_path).and_wrap_original do |m, *args|
        m.call(*args).sub(/^[A-Za-z]:/, "")
      end
      Config.project_root(project_root)
      Config.package_dir(package_dir)

      allow(subject).to receive(:staging_dir).and_return(staging_dir)
      create_directory(staging_dir)

      stub_ohai(platform: "smartos", version: "5.11") do |data|
        data["kernel"]["update"] = architecture
      end
    end

    describe "#id" do
      it "is :pkgsrc" do
        expect(subject.id).to eq(:pkgsrc)
      end
    end

    describe "#package_name" do
      it "includes the name and version" do
        expect(subject.package_name).to eq("project-1.2.3.tgz")
      end
    end

    describe "#write_buildver" do
      it "writes the build version data" do
        subject.write_buildver
        contents = File.read("#{staging_dir}/build-ver")
        expect(contents).to eq("1.2.3-1")
      end
    end

    describe "#write_buildinfo" do
      it "writes the build metaddata" do
        subject.write_buildinfo
        contents = File.read("#{staging_dir}/build-info")
        expect(contents).to match(/OS_VERSION=5.11/)
        expect(contents).to match(/MACHINE_ARCH=x86_64/)
      end
    end

    describe "#write_packlist" do
      it "it writes the list of files" do
        expect(subject).to receive(:shellout!)
          .with "cd #{project.install_dir} && find . -type l -or -type f | sort >> #{staging_dir}/packlist"
        subject.write_packlist
        expect(File.read("#{staging_dir}/packlist")).to match(%r{@pkgdir /opt/project})
      end
    end
  end
end
