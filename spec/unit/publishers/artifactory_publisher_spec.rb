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
        homepage: 'https://www.getchef.com',
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
      before do
        allow(subject).to receive(:packages).and_return(packages)
        Config.artifactory_base_path('com/getchef')
      end

      it 'validates the package' do
        expect(package).to receive(:validate!).once
        subject.publish
      end

      it 'uploads the package' do
        expect(artifact).to receive(:upload).with(
          repository,
          'com/getchef/chef/11.0.6/ubuntu/14.04/chef.deb',
          an_instance_of(Hash),
        ).once

        subject.publish
      end

      context 'when an alternate platform and platform version are provided' do
        subject do
          described_class.new(path,
            repository: repository,
            platform: 'debian',
            platform_version: '7',
          )
        end

        it 'overrides the platform and platform version used for publishing' do
          expect(artifact).to receive(:upload).with(
            repository,
            'com/getchef/chef/11.0.6/debian/7/chef.deb',
            an_instance_of(Hash),
          ).once

          subject.publish
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
