require 'spec_helper'

module Omnibus
  describe Packager::Makeself do
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

    let(:project_root) { "#{tmp_path}/project/root" }
    let(:package_dir)  { "#{tmp_path}/package/dir" }
    let(:staging_dir)  { "#{tmp_path}/staging/dir" }

    before do
      Config.project_root(project_root)
      Config.package_dir(package_dir)

      allow(subject).to receive(:staging_dir).and_return(staging_dir)
      create_directory(staging_dir)
    end

    describe '#id' do
      it 'is :makeself' do
        expect(subject.id).to eq(:makeself)
      end
    end

    describe '#package_name' do
      before do
        allow(subject).to receive(:safe_architecture).and_return('x86_64')
      end

      it 'includes the name, version, and build iteration' do
        expect(subject.package_name).to eq('project-1.2.3_2.x86_64.run')
      end
    end

    describe '#write_post_extract_file' do
      it 'generates the file' do
        subject.write_post_extract_file
        expect("#{staging_dir}/post_extract.sh").to be_a_file
        expect("#{staging_dir}/post_extract.sh").to be_an_executable
      end

      it 'has the correct content' do
        subject.write_post_extract_file
        contents = File.read("#{staging_dir}/post_extract.sh")

        expect(contents).to include("DEST_DIR=/opt/project")
        expect(contents).to include("CONFIG_DIR=/etc/project")
      end
    end

    describe '#create_makeself_package' do
      before do
        allow(subject).to receive(:shellout!)
        allow(Dir).to receive(:chdir) { |_, &b| b.call }
      end

      it 'logs a message' do
        output = capture_logging { subject.create_makeself_package }
        expect(output).to include('Creating makeself package')
      end

      it 'uses the correct command' do
        expect(subject).to receive(:shellout!)
          .with(/makeself\.sh/)
        subject.create_makeself_package
      end
    end
  end
end
