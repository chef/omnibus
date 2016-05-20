require "spec_helper"

module Omnibus
  describe S3Publisher do
    let(:path) { "/path/to/files/*.deb" }

    let(:package) do
      double(Package,
        path: "/path/to/files/chef.deb",
        name: "chef.deb",
        content: "BINARY",
        validate!: true
      )
    end

    let(:metadata) do
      Metadata.new(package,
        name: "chef",
        friendly_name: "Chef",
        homepage: "https://getchef.com",
        version: "11.0.6",
        basename: "chef.deb",
        platform: "ubuntu",
        platform_version: "14.04",
        arch: "x86_64",
        sha1: "SHA1",
        md5: "ABCDEF123456"
      )
    end

    let(:packages) { [package] }

    let(:client) { double("Aws::S3::Resource") }

    before do
      allow(package).to receive(:metadata).and_return(metadata)
      allow(subject).to receive(:client).and_return(client)
      allow(subject).to receive(:store_object)
    end

    subject { described_class.new(path) }

    describe '#publish' do
      before { allow(subject).to receive(:packages).and_return(packages) }

      it "validates the package" do
        expect(package).to receive(:validate!).once
        subject.publish
      end

      it "uploads the metadata" do
        expect(subject).to receive(:store_object).with(
          "ubuntu/14.04/x86_64/chef.deb/chef.deb.metadata.json",
          FFI_Yajl::Encoder.encode(package.metadata.to_hash, pretty: true),
          nil,
          "private"
        ).once

        subject.publish
      end

      it "uploads the package" do
        expect(subject).to receive(:store_object).with(
          "ubuntu/14.04/x86_64/chef.deb/chef.deb",
          package.content,
          package.metadata[:md5],
          "private"
        ).once

        subject.publish
      end

      context "when the upload is set to public" do
        subject { described_class.new(path, acl: "public") }

        it "sets the access control to public_read" do
          expect(subject).to receive(:store_object).with(
            "ubuntu/14.04/x86_64/chef.deb/chef.deb.metadata.json",
            FFI_Yajl::Encoder.encode(package.metadata.to_hash, pretty: true),
            nil,
            "public-read"
          ).once

          subject.publish
        end
      end

      context "when the upload is set to a nonsensical value" do
        subject { described_class.new(path, acl: "baconbits") }

        it "sets the access control to private" do
          expect(subject).to receive(:store_object).with(
            "ubuntu/14.04/x86_64/chef.deb/chef.deb.metadata.json",
            FFI_Yajl::Encoder.encode(package.metadata.to_hash, pretty: true),
            nil,
            "private"
          ).once

          subject.publish
        end
      end

      context "when a block is given" do
        it "yields the package to the block" do
          block = ->(package) { package.do_something! }
          expect(package).to receive(:do_something!).once
          subject.publish(&block)
        end
      end
    end
  end
end
