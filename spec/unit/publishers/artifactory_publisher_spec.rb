require 'spec_helper'

module Omnibus
  describe ArtifactoryPublisher do
    let(:path) { '/path/to/files/*.deb' }

    let(:repository) { 'REPO' }

    let(:package) do
      double(Package,
        path: '/path/to/files/chef.deb',
        name: 'chef.deb',
        content: 'BINARY',
        validate!: true,
      )
    end

    let(:metadata) do
      Package::Metadata.new(package,
        name: 'chef',
        friendly_name: 'Chef',
        homepage: 'https://getchef.com',
        version: '11.0.6',
        basename: 'chef.deb',
        platform: 'ubuntu',
        platform_version: '14.04',
        arch: 'x86_64',
        sha128: 'SHA128',
        md5: 'ABCDEF123456',
      )
    end

    let(:packages) { [package] }

    let(:client) { double('Artifactory', artifact_upload_with_checksum: nil) }

    before do
      package.stub(:metadata).and_return(metadata)
      subject.stub(:client).and_return(client)
    end

    after { Config.reset! }

    subject { described_class.new(path, repository: repository) }

    describe '#publish' do
      before { subject.stub(:packages).and_return(packages) }

      it 'validates the package' do
        expect(package).to receive(:validate!).once
        subject.publish
      end

      it 'uploads the package' do
        expect(client).to receive(:artifact_upload_with_checksum).with(
          repository,
          package.path,
          'com/getchef/chef/11.0.6/chef.deb',
          'SHA128',
          an_instance_of(Hash)
        ).once

        subject.publish
      end

      context 'when the metadata is from an older version of Omnibus' do
        before { package.metadata.stub(:[]).with(:homepage).and_return(nil) }

        it 'raises an exception' do
          expect { subject.publish }.to raise_error(OldMetadata)
        end
      end

      context 'when a block is given' do
        it 'yields the package to the block' do
          block = ->(package) { package.do_something! }
          expect(package).to receive(:do_something!).once
          subject.publish(&block)
        end
      end
    end
  end
end
