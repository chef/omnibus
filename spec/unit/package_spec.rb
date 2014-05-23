require 'spec_helper'

module Omnibus
  describe Package do
    let(:path) { '/path/to/files/thing.deb' }

    subject { described_class.new(path) }

    describe '.initialize' do
      it 'sets the path' do
        expect(subject.instance_variables).to include(:@path)
      end
    end

    describe '#name' do
      it 'returns the basename of the file' do
        expect(subject.name).to eq('thing.deb')
      end
    end

    describe '#md5' do
      let(:md5) { 'abcdef123456' }

      before { subject.stub(:digest).with(path, :md5).and_return(md5) }

      it 'returns the md5 of the package at the path' do
        expect(subject.md5).to eq(md5)
      end
    end

    describe '#sha256' do
      let(:sha256) { 'abcdef123456' }

      before { subject.stub(:digest).with(path, :sha256).and_return(sha256) }

      it 'returns the sha256 of the package at the path' do
        expect(subject.sha256).to eq(sha256)
      end
    end

    describe '#sha512' do
      let(:sha512) { 'abcdef123456' }

      before { subject.stub(:digest).with(path, :sha512).and_return(sha512) }

      it 'returns the sha512 of the package at the path' do
        expect(subject.sha512).to eq(sha512)
      end
    end

    describe '#content' do
      context 'when the file exists' do
        let(:content) { 'BINARY' }

        before { IO.stub(:read).with(path).and_return(content) }

        it 'reads the file' do
          expect(subject.content).to eq(content)
        end
      end

      context 'when the file does not exist' do
        before { IO.stub(:read).and_raise(Errno::ENOENT) }

        it 'raises an exception' do
          expect { subject.content }.to raise_error(NoPackageFile)
        end
      end
    end

    describe '#metadata' do
      let(:content) { '{ "platform": "ubuntu" }' }

      before { IO.stub(:read).with(subject.metadata_path).and_return(content) }

      it 'returns a Hash' do
        expect(subject.metadata).to be_a(Hash)
      end

      it 'reads the information in the file' do
        expect(subject.metadata[:platform]).to eq('ubuntu')
      end
    end

    describe '#raw_metadata' do
      context 'when the file exists' do
        let(:content) { 'metadata' }

        before do
          IO.stub(:read).with(subject.metadata_path).and_return(content)
        end

        it 'reads the file' do
          expect(subject.raw_metadata).to eq(content)
        end
      end

      context 'when the file does not exist' do
        before { IO.stub(:read).and_raise(Errno::ENOENT) }

        it 'raises an exception' do
          expect { subject.raw_metadata }.to raise_error(NoPackageMetadataFile)
        end
      end
    end

    describe '#metadata_path' do
      it 'is the full path + .metadata.json' do
        expect(subject.metadata_path).to eq("#{path}.metadata.json")
      end
    end

    describe '#metadata_name' do
      it 'is the basename of the metadata' do
        expect(subject.metadata_name).to eq('thing.deb.metadata.json')
      end
    end
  end
end
