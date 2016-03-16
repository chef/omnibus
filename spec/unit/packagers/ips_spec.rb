require 'spec_helper'

module Omnibus
  describe Packager::IPS, focus: true do
    let(:project) do
      Project.new.tap do |project|
        project.name('project')
        project.homepage('https://example.com')
        project.install_dir('/opt/project')
        project.build_version('1.2.3')
        project.build_iteration('2')
        project.maintainer('Chef Software')
      end
    end

    subject { described_class.new(project) }

    let(:project_root) { File.join(tmp_path, 'project/root') }
    let(:staging_dir)  { File.join(tmp_path, 'staging/dir') }

    before do
      Config.project_root(project_root)

      allow(subject).to receive(:staging_dir).and_return(staging_dir)
      create_directory(staging_dir)
    end

    it '#id is :IPS' do
      expect(subject.id).to eq(:ips)
    end

    describe "#generate_pkg_metadata" do
      it "should create metadata correctly" do
        subject.generate_pkg_metadata
        manifest_file = File.join(staging_dir, "gen.manifestfile")
        manifest_file_contents = File.read(manifest_file)
        expect(File.exist?(manifest_file)).to be(true)
        expect(manifest_file_contents).to include("set name=pkg.fmri value=developer/versioning/project@2.3,2.3-2")
        expect(manifest_file_contents).to include("set name=variant.arch value=i386")
      end
    end

    it "should run subfunctions in the correct order during build" do
      expect(subject).to receive(:generate_pkg_manifest).ordered
      expect(subject).to receive(:create_ips_repo).ordered
      expect(subject).to receive(:publish_ips_pkg).ordered
      expect(subject).to receive(:view_repo_info).ordered
      expect(subject).to receive(:publish_as_pkg_archive).ordered
      subject.build_me
    end

    it "should run subfunctions in the correct order during manifest creation" do
      expect(subject).to receive(:generate_pkg_metadata).ordered
      expect(subject).to receive(:generate_pkg_contents).ordered
      expect(subject).to receive(:generate_pkg_deps).ordered
      expect(subject).to receive(:check_pkg_manifest).ordered
      subject.generate_pkg_manifest
    end

    # Bunch of methods on the subject are just calls to shellout.
    # We are not testing the executed commands here by copy pasting them from
    # code to here :)

    it "should create transform file correctly" do
      subject.create_transform_file
      transform_file = File.join(staging_dir, "doc-transform")
      transform_file_contents = File.read(transform_file)
      expect(File.exist?(transform_file)).to be(true)
      expect(transform_file_contents).to include("<transform dir path=opt$ -> edit group bin sys>")
    end

    describe '#package_name' do
      before do
        expect(subject.package_name).to eq('project.p5p')
      end
    end
  end
end
