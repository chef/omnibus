require 'spec_helper'

module Omnibus
  describe S3Publisher do
    let(:path) { '/path/to/files/*.deb' }

    let(:s3_access_key) { 'ACCESS_KEY' }
    let(:s3_secret_key) { 'SECRET_KEY' }
    let(:s3_bucket)     { 'BUCKET' }

    let(:package) do
      double(Package,
        name: 'chef.deb',
        content: 'BINARY',
        raw_metadata: 'METADATA',
        metadata_name: 'chef.deb.metadata.json',
        metadata: {
          platform: 'ubuntu',
          platform_version: '14.04',
          arch: 'x86_64',
          md5: 'ABCDEF123456',
        },
        validate!: true,
      )
    end

    let(:packages) { [package] }

    let(:client) { double('UberS3', store: nil) }

    before do
      Config.reset!
      Config.release_s3_access_key = s3_access_key
      Config.release_s3_secret_key = s3_secret_key
      Config.release_s3_bucket     = s3_bucket

      subject.stub(:client).and_return(client)
    end

    after { Config.reset! }

    subject { described_class.new(path) }

    describe '#initialize' do
      it 'raises an exception when release_s3_access_key is missing' do
        Config.release_s3_access_key = nil
        expect { described_class.new(path) }
          .to raise_error(InvalidS3ReleaseConfiguration)
      end

      it 'raises an exception when release_s3_secret_key is missing' do
        Config.release_s3_secret_key = nil
        expect { described_class.new(path) }
          .to raise_error(InvalidS3ReleaseConfiguration)
      end

      it 'raises an exception when release_s3_bucket is missing' do
        Config.release_s3_bucket = nil
        expect { described_class.new(path) }
          .to raise_error(InvalidS3ReleaseConfiguration)
      end

      it 'does not raise an error when the config is okay' do
        expect { described_class.new(path) }.to_not raise_error
      end
    end

    describe '#publish' do
      before { subject.stub(:packages).and_return(packages) }

      it 'validates the package' do
        expect(package).to receive(:validate!).once
        subject.publish
      end

      it 'uploads the metadata' do
        expect(client).to receive(:store).with(
          'ubuntu/14.04/x86_64/chef.deb/chef.deb.metadata.json',
          package.raw_metadata,
          access: :private,
        ).once

        subject.publish
      end

      it 'uploads the package' do
        expect(client).to receive(:store).with(
          'ubuntu/14.04/x86_64/chef.deb/chef.deb',
          package.content,
          access: :private,
          content_md5: package.metadata[:md5],
        ).once

        subject.publish
      end

      context 'when the upload is set to public' do
        subject { described_class.new(path, s3_access: 'public') }

        it 'sets the access control to public_read' do
          expect(client).to receive(:store).with(
            'ubuntu/14.04/x86_64/chef.deb/chef.deb.metadata.json',
            package.raw_metadata,
            access: :public_read,
          ).once

          subject.publish
        end
      end

      context 'when the upload is set to a nonsensical value' do
        subject { described_class.new(path, s3_access: 'baconbits') }

        it 'sets the access control to private' do
          expect(client).to receive(:store).with(
            'ubuntu/14.04/x86_64/chef.deb/chef.deb.metadata.json',
            package.raw_metadata,
            access: :private,
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
