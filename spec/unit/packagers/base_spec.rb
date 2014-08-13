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
      end
    end

    before do
      # Force the Dir.mktmpdir call on staging_dir
      allow(Dir).to receive(:mktmpdir).and_return('/tmp/dir')
    end

    subject { described_class.new(project) }

    it 'includes Digestable' do
      expect(subject).to be_a(Digestable)
    end

    it 'includes Logging' do
      expect(subject).to be_a(Logging)
    end

    it 'includes Templating' do
      expect(subject).to be_a(Templating)
    end

    it 'includes Util' do
      expect(subject).to be_a(Util)
    end

    describe '.id' do
      it 'defines the id method on the instance' do
        described_class.id(:base)
        expect(subject.id).to eq(:base)
      end
    end

    describe '.setup' do
      it 'sets the value of the block' do
        block = proc {}
        described_class.setup(&block)

        expect(described_class.setup).to eq(block)
      end
    end

    describe '.build' do
      it 'sets the value of the block' do
        block = proc {}
        described_class.build(&block)

        expect(described_class.build).to eq(block)
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

    describe '#run!' do
      before do
        allow(subject).to receive(:purge_directory)
        allow(subject).to receive(:remove_directory)
        allow(subject).to receive(:render_metadata!)

        allow(described_class).to receive(:setup).and_return(proc {})
        allow(described_class).to receive(:build).and_return(proc {})
      end

      it 'calls the methods in order' do
        expect(described_class).to receive(:setup).ordered
        expect(described_class).to receive(:build).ordered
        subject.run!
      end
    end

    describe '#staging_dir' do
      it 'creates a temporary directory' do
        expect(Dir).to receive(:mktmpdir)
        subject.send(:staging_dir)
      end
    end

    describe '#resource_path' do
      let(:id) { :base }
      before { allow(subject).to receive(:id).and_return(id) }

      context 'when a local resource exists' do
        let(:resources_path) { '/resources/path' }

        before do
          project.resources_path(resources_path)

          allow(File).to receive(:exist?)
            .with(/#{resources_path}/)
            .and_return(true)
        end

        it 'returns the local path' do
          expect(subject.resource_path('foo/bar.erb')).to eq("#{resources_path}/#{id}/foo/bar.erb")
        end
      end

      context 'when a local resource does not exist' do
        it 'returns the remote path' do
          expect(subject.resource_path('foo/bar.erb')).to eq("#{Omnibus.source_root.join("resources/#{id}/foo/bar.erb")}")
        end
      end
    end

    describe '#resoures_path' do
      let(:id) { :base }
      let(:resources_path) { '/resources/path' }

      before do
        project.resources_path(resources_path)
        allow(subject).to receive(:id).and_return(id)
      end

      it 'returns the path with the id' do
        expect(subject.resources_path).to eq("#{resources_path}/#{id}")
      end
    end
  end
end
