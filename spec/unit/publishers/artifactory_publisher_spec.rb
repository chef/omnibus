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
        iteration: 1,
        basename: 'chef.deb',
        platform: 'ubuntu',
        platform_version: '14.04',
        arch: 'x86_64',
        sha1: 'SHA1',
        md5: 'ABCDEF123456',
      )
    end

    let(:packages) { [package] }
    let(:client)   { double('Artifactory::Client') }
    let(:artifact) { double('Artifactory::Resource::Artifact', upload: nil) }

    before do
      allow(subject).to receive(:client).and_return(client)
      allow(subject).to receive(:artifact_for).and_return(artifact)
      allow(package).to receive(:metadata).and_return(metadata)
    end

    subject { described_class.new(path, repository: repository) }

    describe '#publish' do
      before { allow(subject).to receive(:packages).and_return(packages) }

      it 'validates the package' do
        expect(package).to receive(:validate!).once
        subject.publish
      end

      it 'uploads the package' do
        expect(artifact).to receive(:upload).with(
          repository,
          'com/getchef/chef/11.0.6/ubuntu/14.04/chef.deb',
          an_instance_of(Hash)
        ).once

        subject.publish
      end

      context 'when the metadata is from an older version of Omnibus' do
        before { allow(package.metadata).to receive(:[]).with(:homepage).and_return(nil) }

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
