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
      Metadata.new(package,
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
    let(:build)    { double('Artifactory::Resource::Build') }

    before do
      allow(subject).to receive(:client).and_return(client)
      allow(subject).to receive(:artifact_for).and_return(artifact)
      allow(subject).to receive(:build_for).and_return(build)
      allow(package).to receive(:metadata).and_return(metadata)
      allow(build).to   receive(:save)
    end

    subject { described_class.new(path, repository: repository) }

    describe '#publish' do
      before do
        allow(subject).to receive(:packages).and_return(packages)
        Config.artifactory_base_path('com/getchef')
        Config.publish_retries(1)
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

      it 'it creates a build object for all packages' do
        expect(build).to receive(:save).once
        subject.publish
      end

      context 'when no packages exist' do
        let(:packages) { [] }

        it 'does nothing' do
          expect(artifact).to_not receive(:upload)
          expect(build).to_not    receive(:save)
        end
      end

      context 'when upload fails' do
        before do
          Config.publish_retries(3)

          # This is really ugly but there is no easy way to stub a method to
          # raise an exception a set number of times.
          @times = 0
          allow(artifact).to receive(:upload) do
            @times += 1;
            raise Artifactory::Error::HTTPError.new('status' => '409', 'message' => 'CONFLICT') unless @times > 1
          end
        end

        it 'retries the upload ' do
          output = capture_logging { subject.publish }
          expect(output).to include('Retrying failed publish')
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
