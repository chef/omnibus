require 'stringio'

module Omnibus
  describe Packager::Base do
    let(:project) do
      Project.new.tap do |project|
        project.name('project')
        project.install_dir('/opt/project')
        project.build_version('1.2.3')
        project.build_iteration('2')
        project.maintainer('Chef Software')
        project.mac_pkg_identifier('com.getchef.project')
      end
    end

    before do
      # Force the Dir.mktmpdir call on staging_dir
      allow(Dir).to receive(:mktmpdir).and_return('/tmp/dir')
    end

    subject { described_class.new(project) }

    it 'includes Util' do
      expect(subject).to be_a(Util)
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
      before { allow(FileUtils).to receive(:mkdir_p) }

      it 'creates the directory' do
        expect(FileUtils).to receive(:mkdir_p).with('/foo/bar')
        subject.create_directory('/foo/bar')
      end

      it 'returns the path' do
        expect(subject.create_directory('/foo/bar')).to eq('/foo/bar')
      end
    end

    describe '#remove_directory' do
      before { allow(FileUtils).to receive(:rm_rf) }

      it 'remove the directory' do
        expect(FileUtils).to receive(:rm_rf).with('/foo/bar')
        subject.remove_directory('/foo/bar')
      end
    end

    describe '#purge_directory' do
      before do
        allow(subject).to receive(:remove_directory)
        allow(subject).to receive(:create_directory)
      end

      it 'removes and creates the directory' do
        expect(subject).to receive(:remove_directory).with('/foo/bar')
        expect(subject).to receive(:create_directory).with('/foo/bar')
        subject.purge_directory('/foo/bar')
      end
    end

    describe '#copy_file' do
      before { allow(FileUtils).to receive(:cp) }

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
        allow(FileUtils).to receive(:cp_r)
        allow(FileSyncer).to receive(:glob).and_return(['baz/file'])
      end

      it 'copies the directory' do
        expect(FileUtils).to receive(:cp_r).with(['baz/file'], 'bar')
        subject.copy_directory('baz', 'bar')
      end
    end

    describe '#remove_file' do
      before { allow(FileUtils).to receive(:rm_f) }

      it 'removes the file' do
        expect(FileUtils).to receive(:rm_f).with('/foo/bar')
        subject.remove_file('/foo/bar')
      end
    end

    describe '#execute' do
      before { allow(subject).to receive(:shellout!) }

      it 'shellsout' do
        expect(subject).to receive(:shellout!)
          .with('echo "hello"', timeout: 3600, cwd: anything)
        subject.execute('echo "hello"')
      end
    end

    describe '#assert_presence!' do
      it 'raises a MissingAsset exception when the file does not exist' do
        allow(File).to receive(:exist?).and_return(false)
        expect { subject.assert_presence!('foo') }.to raise_error(MissingAsset)
      end
    end

    describe '#run!' do
      before do
        allow(described_class).to receive(:validate).and_return(proc {})
        allow(described_class).to receive(:setup).and_return(proc {})
        allow(described_class).to receive(:build).and_return(proc {})
        allow(described_class).to receive(:clean).and_return(proc {})
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
      it 'creates a temporary directory' do
        expect(Dir).to receive(:mktmpdir)
        subject.send(:staging_dir)
      end
    end

    describe '#staging_resources_path' do
      it 'is base/Resources under package temp' do
        name = "/tmp/dir/Resources"
        expect(subject.send(:staging_resources_path)).to eq(name)
      end
    end

    describe '#resource' do
      it 'prefixes to the resources_path' do
        path = '/tmp/dir/Resources/icon.png'
        expect(subject.send(:resource, 'icon.png')).to eq(path)
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
        before { allow(project).to receive(:resources_path).and_return('project/specific') }
        it 'is the project resources_path, underscored_name, and Resources' do
          path = 'project/specific/base/Resources'
          expect(subject.send(:resources_path)).to eq(File.expand_path(path))
        end
      end
    end
  end
end
