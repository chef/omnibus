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
        expect(subject.package_name).to eq('project-1.2.3_2.x86_64.sh')
      end
    end

    describe '#write_scripts' do
      before do
        create_file("#{project_root}/package-scripts/project/makeselfinst") { 'Contents of makeselfinst' }
      end

      it 'copies the scripts into the STAGING dir' do
        subject.write_scripts
        expect("#{staging_dir}/makeselfinst").to be_a_file
      end

      it 'has the correct content' do
        subject.write_scripts
        contents = File.read("#{staging_dir}/makeselfinst")

        expect(contents).to include('Contents of makeselfinst')
      end
    end

    describe '#write_scripts' do
      context 'when scripts are given' do
        let(:scripts) { %w( makeselfinst ) }
        before do
          scripts.each do |script_name|
            create_file("#{project_root}/package-scripts/project/#{script_name}") do
              "Contents of #{script_name}"
            end
          end
        end

        it 'writes the scripts into the staging dir' do
          subject.write_scripts

          scripts.each do |script_name|
            script_file = "#{staging_dir}/#{script_name}"
            contents = File.read(script_file)
            expect(contents).to include("Contents of #{script_name}")
          end
        end
      end

      context 'when scripts with default omnibus naming are given' do
        let(:default_scripts) { %w( postinst ) }
        before do
          default_scripts.each do |script_name|
            create_file("#{project_root}/package-scripts/project/#{script_name}") do
              "Contents of #{script_name}"
            end
          end
        end

        it 'writes the scripts into the staging dir' do
          subject.write_scripts

          default_scripts.each do |script_name|
            mapped_name = Packager::Makeself::SCRIPT_MAP[script_name.to_sym]
            script_file = "#{staging_dir}/#{mapped_name}"
            contents = File.read(script_file)
            expect(contents).to include("Contents of #{script_name}")
          end
        end
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
