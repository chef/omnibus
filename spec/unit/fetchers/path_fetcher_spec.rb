require 'spec_helper'

module Omnibus
  describe PathFetcher do
    let(:source_path) { '/local/path' }
    let(:project_dir) { '/project/dir' }
    let(:build_dir) { '/build/dir' }

    let(:manifest_entry) do
      double(ManifestEntry,
        name: 'software',
        locked_version: nil,
        locked_source: { path: source_path })
    end

    subject { described_class.new(manifest_entry, project_dir, build_dir) }

    describe '#fetch_required?' do
      context 'when the SHAs match' do
        before do
          allow(subject).to receive(:target_shasum).and_return('abcd1234')
          allow(subject).to receive(:destination_shasum).and_return('abcd1234')
        end

        it 'returns false' do
          expect(subject.fetch_required?).to be(false)
        end
      end

      context 'when the SHAs do not match' do
        before do
          allow(subject).to receive(:target_shasum).and_return('abcd1234')
          allow(subject).to receive(:destination_shasum).and_return('efgh5678')
        end

        it 'returns true' do
          expect(subject.fetch_required?).to be_truthy
        end
      end
    end

    describe '#version_guid' do
      it 'returns the path' do
        expect(subject.version_guid).to eq("path:#{source_path}")
      end
    end

    describe '#clean' do
      before do
        allow(FileUtils).to receive(:rm_rf)
        allow(subject).to receive(:fetch)
      end

      context 'when the directory exists' do
        before do
          allow(File).to receive(:exist?).with(project_dir).and_return(true)
        end

        it 'removes the directory' do
          expect(FileUtils).to receive(:rm_rf).with(project_dir).once
          subject.clean
        end

        it 'returns true' do
          expect(subject.clean).to be_truthy
        end
      end

      context 'when the directory does not exist' do
        before do
          allow(File).to receive(:exist?).with(project_dir).and_return(false)
        end

        it 'does not remove the directory' do
          expect(FileUtils).to_not receive(:rm_rf)
          subject.clean
        end

        it 'returns false' do
          expect(subject.clean).to be(false)
        end
      end
    end

    describe '#fetch' do
      before do
        allow(subject).to receive(:create_required_directories)
        allow(FileSyncer).to receive(:sync)
      end

      it 'copies the new files over' do
        expect(FileSyncer).to receive(:sync).with(source_path, project_dir, {})
        subject.fetch
      end
    end

    describe '#version_for_cache' do
      let(:shasum) { 'abcd1234' }

      before do
        allow(subject).to receive(:digest_directory)
          .with(project_dir, :sha256)
          .and_return(shasum)
      end

      it 'returns the shasum of the project_dir' do
        expect(subject.version_for_cache).to eq("path:#{source_path}|shasum:#{shasum}")
      end
    end
  end
end
