require 'spec_helper'

module Omnibus
  describe Package::Metadata do
    let(:instance) do
      double(Package::Metadata,
        path: '/path/to/package.deb.metadata.json',
      )
    end

    let(:package) do
      double(Package,
        name:   'package',
        path:   '/path/to/package.deb',
        md5:    'abc123',
        sha1:   'abc123',
        sha256: 'abcd1234',
        sha512: 'abcdef123456',
      )
    end

    let(:data) { { foo: 'bar' } }

    subject { described_class.new(package, data) }

    describe '.generate' do
      it 'writes out the file' do
        described_class.stub(:new).and_return(instance)
        expect(instance).to receive(:save).once

        described_class.generate(package, data)
      end
    end

    describe '.for_package' do
      it 'raises an exception when the file does not exist' do
        File.stub(:read).and_raise(Errno::ENOENT)
        expect { described_class.for_package(package) }
          .to raise_error(NoPackageMetadataFile)
      end

      it 'returns a metadata object' do
        File.stub(:read).and_return('{ "platform": "ubuntu" }')
        expect(described_class.for_package(package)).to be_a(described_class)
      end

      it 'loads the metadata from disk' do
        File.stub(:read).and_return('{ "platform": "ubuntu" }')
        instance = described_class.for_package(package)

        expect(instance[:platform]).to eq('ubuntu')
      end
    end

    describe '.path_for' do
      it 'returns the postfixed .metadata.json' do
        expect(described_class.path_for(package))
          .to eq('/path/to/package.deb.metadata.json')
      end
    end

    describe '#name' do
      it 'returns the basename of the package' do
        expect(subject.name).to eq('package.deb.metadata.json')
      end
    end

    describe '#path' do
      it 'delegates to .path_for' do
        expect(described_class).to receive(:path_for).once
        subject.path
      end
    end

    describe '#save' do
      let(:file) { double(File) }

      before { File.stub(:open).and_yield(file) }

      it 'saves the file to disk' do
        expect(file).to receive(:write).once
        subject.save
      end
    end

    describe '#to_json' do
      it 'generates pretty JSON' do
        expect(subject.to_json).to eq <<-EOH.gsub(/^ {10}/, '').strip
          {
            "foo": "bar"
          }
        EOH
      end
    end
  end

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

      before { IO.stub(:read).and_return(content) }

      it 'returns a Metadata object' do
        expect(subject.metadata).to be_a(Package::Metadata)
      end

      it 'reads the information in the file' do
        expect(subject.metadata[:platform]).to eq('ubuntu')
      end
    end
  end
end
