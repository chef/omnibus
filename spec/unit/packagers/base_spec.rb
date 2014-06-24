require 'stringio'

module Omnibus
  describe Packager::Base do
    before do
      Config.package_tmp('pkg-tmp')
    end

    let(:project) do
      double(Project,
        name: 'hamlet',
        build_version: '1.0.0',
        iteration: '12902349',
        mac_pkg_identifier: 'com.chef.hamlet',
        install_path: '/opt/hamlet',
        package_scripts_path: 'package-scripts',
        files_path: 'files',
        resources_path: nil,
        friendly_name: 'HAMLET',
      )
    end

    subject { described_class.new(project) }

    it 'includes Util' do
      expect(subject).to be_a(Util)
    end

    it 'delegates #name to @project' do
      expect(subject.name).to eq(project.name)
    end

    it 'delegates #friendly_name to @project' do
      expect(subject.friendly_name).to eq(project.friendly_name)
    end

    it 'delegates #version to @project' do
      expect(subject.version).to eq(project.build_version)
    end

    it 'delegates #iteration to @project' do
      expect(subject.iteration).to eq(project.iteration)
    end

    it 'delegates #identifer to @project' do
      expect(subject.identifier).to eq(project.mac_pkg_identifier)
    end

    it 'delegates #files_path to @project' do
      expect(subject.files_path).to eq(project.files_path)
    end


    describe '.setup' do
      it 'sets the value of the block' do
        block = proc {}
        described_class.setup(&block)

        expect(described_class.setup).to eq(block)
      end
    end

    describe '.validate' do
      it 'sets the value of the block' do
        block = proc {}
        described_class.validate(&block)

        expect(described_class.validate).to eq(block)
      end
    end

    describe '.build' do
      it 'sets the value of the block' do
        block = proc {}
        described_class.build(&block)

        expect(described_class.build).to eq(block)
      end

      it 'is a required phase' do
        described_class.instance_variable_set(:@build, nil)
        expect { described_class.build }.to raise_error(AbstractMethod)
      end
    end

    describe '.clean' do
      it 'sets the value of the block' do
        block = proc {}
        described_class.clean(&block)

        expect(described_class.clean).to eq(block)
      end
    end

    describe '#create_directory' do
      before { FileUtils.stub(:mkdir_p) }

      it 'creates the directory' do
        expect(FileUtils).to receive(:mkdir_p).with('/foo/bar')
        subject.create_directory('/foo/bar')
      end

      it 'returns the path' do
        expect(subject.create_directory('/foo/bar')).to eq('/foo/bar')
      end
    end

    describe '#remove_directory' do
      before { FileUtils.stub(:rm_rf) }

      it 'remove the directory' do
        expect(FileUtils).to receive(:rm_rf).with('/foo/bar')
        subject.remove_directory('/foo/bar')
      end
    end

    describe '#purge_directory' do
      before do
        subject.stub(:remove_directory)
        subject.stub(:create_directory)
      end

      it 'removes and creates the directory' do
        expect(subject).to receive(:remove_directory).with('/foo/bar')
        expect(subject).to receive(:create_directory).with('/foo/bar')
        subject.purge_directory('/foo/bar')
      end
    end

    describe '#copy_file' do
      before { FileUtils.stub(:cp) }

      it 'copies the file' do
        expect(FileUtils).to receive(:cp).with('foo', 'bar')
        subject.copy_file('foo', 'bar')
      end

      it 'returns the destination path' do
        expect(subject.copy_file('foo', 'bar')).to eq('bar')
      end
    end

    describe '#copy_directory' do
      before do
        FileUtils.stub(:cp_r)
        Dir.stub(:[]).and_return(['baz/file'])
      end

      it 'copies the directory' do
        expect(FileUtils).to receive(:cp_r).with(['baz/file'], 'bar')
        subject.copy_directory('baz', 'bar')
      end
    end

    describe '#render_template' do
      it 'return when source is not an erb template' do
        expect(File).not_to receive(:open)
        subject.render_template('source.txt')
      end

      shared_examples_for 'render_template' do
        let(:output) { StringIO.new }

        before do
          input = StringIO.new
          input.write('<%= friendly_name %>')
          input.rewind

          File.stub(:open).with(source_path).and_yield(input)
          File.stub(:open).with(expected_destination_path, 'w').and_yield(output)

          expect(subject).to receive(:remove_file).with(source_path)
        end

        it 'should render correctly' do
          subject.render_template(source_path, destination_path)
          expect(output.string).to eq('HAMLET')
        end
      end

      context 'when destination is specified' do
        let(:source_path) { 'source.txt.erb' }
        let(:destination_path) { 'destination.txt' }
        let(:expected_destination_path) { destination_path }

        include_examples 'render_template'
      end

      context 'when destination is not specified' do
        let(:source_path) { 'source.txt.erb' }
        let(:destination_path) { nil }
        let(:expected_destination_path) { 'source.txt' }

        include_examples 'render_template'
      end
    end

    describe '#remove_file' do
      before { FileUtils.stub(:rm_f) }

      it 'removes the file' do
        expect(FileUtils).to receive(:rm_f).with('/foo/bar')
        subject.remove_file('/foo/bar')
      end
    end

    describe '#execute' do
      before { subject.stub(:shellout!) }

      it 'shellsout' do
        expect(subject).to receive(:shellout!)
          .with('echo "hello"', timeout: 3600, cwd: anything)
        subject.execute('echo "hello"')
      end
    end

    describe '#assert_presence!' do
      it 'raises a MissingAsset exception when the file does not exist' do
        File.stub(:exist?).and_return(false)
        expect { subject.assert_presence!('foo') }.to raise_error(MissingAsset)
      end
    end

    describe '#run!' do
      before do
        described_class.stub(:validate).and_return(proc {})
        described_class.stub(:setup).and_return(proc {})
        described_class.stub(:build).and_return(proc {})
        described_class.stub(:clean).and_return(proc {})
      end

      it 'calls the methods in order' do
        expect(described_class).to receive(:setup).ordered
        expect(described_class).to receive(:validate).ordered
        expect(described_class).to receive(:build).ordered
        expect(described_class).to receive(:clean).ordered
        subject.run!
      end
    end

    describe '#staging_dir' do
      it 'is the project package tmp and underscored named' do
        name = "#{Config.package_tmp}/base"
        expect(subject.send(:staging_dir)).to eq(File.expand_path(name))
      end
    end

    describe '#staging_resources_path' do
      it 'is base/Resources under package temp' do
        name = "#{Config.package_tmp}/base/Resources"
        expect(subject.send(:staging_resources_path)).to eq(File.expand_path(name))
      end
    end

    describe '#resource' do
      it 'prefixes to the resources_path' do
        path = 'pkg-tmp/base/Resources/icon.png'
        expect(subject.send(:resource, 'icon.png')).to eq(File.expand_path(path))
      end
    end

    describe '#resoures_path' do
      context 'when project does not define resources_path' do
        it 'is the files_path, underscored_name, and Resources' do
          path = "#{project.files_path}/base/Resources"
          expect(subject.send(:resources_path)).to eq(File.expand_path(path))
        end
      end

      context 'when project defines resources_path' do
        before { project.stub(:resources_path).and_return('project/specific') }
        it 'is the project resources_path, underscored_name, and Resources' do
          path = 'project/specific/base/Resources'
          expect(subject.send(:resources_path)).to eq(File.expand_path(path))
        end
      end
    end
  end
end
