require "spec_helper"

module Omnibus
  describe Compressor::TGZ do
    let(:project) do
      Project.new.tap do |project|
        project.name("project")
        project.homepage("https://example.com")
        project.install_dir("/opt/project")
        project.build_version("1.2.3")
        project.build_iteration("2")
        project.maintainer("Chef Software")
      end
    end

    subject { described_class.new(project) }

    let(:project_root) { File.join(tmp_path, "project/root") }
    let(:package_dir)  { File.join(tmp_path, "package/dir") }
    let(:staging_dir)  { File.join(tmp_path, "staging/dir") }

    before do
      create_directory(project_root)
      create_directory(package_dir)
      create_directory(staging_dir)

      allow(project).to receive(:packagers_for_system)
        .and_return([Packager::PKG.new(project)])

      Config.project_root(project_root)
      Config.package_dir(package_dir)

      allow(subject).to receive(:staging_dir)
        .and_return(staging_dir)

      allow(subject).to receive(:shellout!)
    end

    describe '#package_name' do
      it "returns the name of the packager" do
        expect(subject.package_name).to eq("project-1.2.3-2.pkg.tar.gz")
      end
    end

    describe '#write_tgz' do
      before do
        File.open("#{staging_dir}/project-1.2.3-2.pkg", "wb") do |f|
          f.write " " * 1_000_000
        end
      end

      it "generates the file" do
        subject.write_tgz
        expect("#{staging_dir}/project-1.2.3-2.pkg.tar.gz").to be_a_file
      end

      it "has the correct content" do
        subject.write_tgz
        file = File.open("#{staging_dir}/project-1.2.3-2.pkg.tar.gz", "rb")
        contents = file.read
        file.close

        expect(contents).to include("\x1F\x8B\b\x00".force_encoding("ASCII-8BIT"))
      end
    end
  end
end
