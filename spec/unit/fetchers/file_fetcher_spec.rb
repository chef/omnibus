require "spec_helper"

module Omnibus
  describe FileFetcher do
    let(:source_file) { "/local/file" }
    let(:target_file) { "/project/dir/file" }
    let(:project_dir) { "/project/dir" }
    let(:build_dir) { "/build/dir" }

    let(:manifest_entry) do
      double(ManifestEntry,
        name: "software",
        locked_version: nil,
        described_version: nil,
        locked_source: { file: source_file })
    end

    subject { described_class.new(manifest_entry, project_dir, build_dir) }

    describe "#fetch_required?" do
      context "when the SHAs match" do
        before do
          allow(subject).to receive(:target_shasum).and_return("abcd1234")
          allow(subject).to receive(:destination_shasum).and_return("abcd1234")
        end

        it "returns false" do
          expect(subject.fetch_required?).to be(false)
        end
      end

      context "when the SHAs do not match" do
        before do
          allow(subject).to receive(:target_shasum).and_return("abcd1234")
          allow(subject).to receive(:destination_shasum).and_return("efgh5678")
        end

        it "returns true" do
          expect(subject.fetch_required?).to be_truthy
        end
      end
    end

    describe "#version_guid" do
      it "returns the path" do
        expect(subject.version_guid).to eq("file:#{source_file}")
      end
    end

    describe "#clean" do
      it "returns true" do
        expect(subject.clean).to be_truthy
      end
    end

    describe "#fetch" do
      before do
        allow(subject).to receive(:create_required_directories)
      end

      it "copies the new files over" do
        expect(FileUtils).to receive(:cp).with(source_file, target_file)
        subject.fetch
      end
    end

    describe "#version_for_cache" do
      let(:shasum) { "abcd1234" }

      before do
        allow(subject).to receive(:digest)
          .with(source_file, :sha256)
          .and_return(shasum)
      end

      it "returns the shasum of the source file" do
        expect(subject.version_for_cache).to eq("file:#{source_file}|shasum:#{shasum}")
      end
    end
  end
end
