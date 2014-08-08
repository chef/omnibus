require 'spec_helper'

module Omnibus
  describe Packager::BFF do
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
      it 'is :bff' do
        expect(subject.id).to eq(:bff)
      end
    end

    describe '#package_name' do
      before do
        allow(subject).to receive(:safe_architecture).and_return('x86_64')
      end

      it 'includes the name, version, and build iteration' do
        expect(subject.package_name).to eq('project.1.2.3.2.x86_64.bff')
      end
    end

    describe '#write_gen_template' do
      before do
        allow(subject).to receive(:safe_architecture).and_return('x86_64')
      end

      let(:gen_file) { "#{staging_dir}/gen.template" }

      it 'generates the file' do
        subject.write_gen_template
        expect(gen_file).to be_a_file
      end

      it 'has the correct content' do
        subject.write_gen_template
        contents = File.read(gen_file)

        expect(contents).to include("Package Name: project")
        expect(contents).to include("Package VRMF: 1.2.3.2")
        expect(contents).to include("Update: N")
        expect(contents).to include("Fileset")
        expect(contents).to include("  Fileset Name: project")
        expect(contents).to include("  Fileset VRMF: 1.2.3.2")
        expect(contents).to include("  Fileset Description: The full stack of project")
        expect(contents).to include("  USRLIBLPPFiles")
        expect(contents).to include("    Configuration Script: /opt/project/bin/postinstall.sh")
        expect(contents).to include("    Unconfiguration Script: /opt/project/bin/unpostinstall.sh")
        expect(contents).to include("  EOUSRLIBLPPFiles")
        expect(contents).to include("  Bosboot required: N")
        expect(contents).to include("  License agreement acceptance required: N")
        expect(contents).to include("  Include license files in this package: N")
        expect(contents).to include("  Requisites:")
        expect(contents).to include("  ROOT Part: Y")
        expect(contents).to include("  ROOTFiles")
        expect(contents).to include("  EOROOTFiles")
        expect(contents).to include("EOFileset")
      end

      context 'when files and directories are present' do
        before do
          create_file("#{staging_dir}/.file1")
          create_file("#{staging_dir}/file2")
          create_directory("#{staging_dir}/.dir1")
          create_directory("#{staging_dir}/dir2")
        end

        it 'writes them into the template' do
          subject.write_gen_template
          contents = File.read(gen_file)

          expect(contents).to include("/.dir1")
          expect(contents).to include("/.file1")
          expect(contents).to include("/dir2")
          expect(contents).to include("/file2")
        end
      end
    end

    describe '#create_bff_file' do
      before do
        allow(subject).to receive(:shellout!)
        allow(Dir).to receive(:chdir) { |_, &b| b.call }
      end

      it 'logs a message' do
        output = capture_logging { subject.create_bff_file }
        expect(output).to include('Creating .bff file')
      end

      it 'uses the correct command' do
        expect(subject).to receive(:shellout!)
          .with(/\/usr\/sbin\/mkinstallp -d/)
        subject.create_bff_file
      end
    end

    describe '#safe_project_name' do
      context 'when the project name is "safe"' do
        it 'returns the value without logging a message' do
          expect(subject.safe_project_name).to eq('project')
          expect(subject).to_not receive(:log)
        end
      end

      context 'when the project name has invalid characters' do
        before { project.name("Pro$ject123.for-realz_2") }

        it 'returns the value without logging a message' do
          output = capture_logging do
            expect(subject.safe_project_name).to eq('pro-ject123.for-realz-2')
          end

          expect(output).to include("The `name' compontent of BFF package names can only include")
        end
      end
    end

    describe '#bff_version' do
      it 'returns the build version up with the build iteration' do
        expect(subject.bff_version).to eq('1.2.3.2')
      end
    end

    describe '#safe_architecture' do
      before do
        stub_ohai(platform: 'ubuntu', version: '12.04') do |data|
          data['kernel']['machine'] = 'i386'
        end
      end

      it 'returns the value from Ohai' do
        expect(subject.safe_architecture).to eq('i386')
      end
    end
  end
end
