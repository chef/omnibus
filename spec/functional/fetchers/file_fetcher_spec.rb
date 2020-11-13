require "spec_helper"

module Omnibus
  describe FileFetcher do
    include_examples "a software"

    let(:source_file) { File.join(tmp_path, "t", "software") }
    let(:target_file) { File.join(project_dir, "software") }

    let(:source) do
      { file: source_file }
    end

    let(:manifest_entry) do
      double(Omnibus::ManifestEntry,
        name: "pathelogical",
        locked_version: nil,
        described_version: nil,
        locked_source: source)
    end

    subject { described_class.new(manifest_entry, project_dir, build_dir) }

    describe "#fetch_required?" do
      context "when the files have different hashes" do
        before do
          create_file(source_file) { "different" }
          create_file(target_file) { "same" }
        end

        it "return true" do
          expect(subject.fetch_required?).to be_truthy
        end
      end

      context "when the files have the same hash" do
        before do
          create_file(source_file) { "same" }
          create_file(target_file) { "same" }
        end

        it "returns false" do
          expect(subject.fetch_required?).to be(false)
        end
      end
    end

    describe "#version_guid" do
      it "includes the source file" do
        expect(subject.version_guid).to eq("file:#{source_file}")
      end
    end

    describe "#fetch" do
      before do
        create_file(source_file)

        remove_file(target_file)
      end

      it "fetches new files" do
        subject.fetch

        expect(target_file).to be_a_file
      end
    end

    describe "#clean" do
      it "returns true" do
        expect(subject.clean).to be_truthy
      end
    end

    describe "#version_for_cache" do
      before do
        create_file(source_file)
      end

      let(:sha) { "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" }

      it "includes the source_file and shasum" do
        expect(subject.version_for_cache).to eq("file:#{source_file}|shasum:#{sha}")
      end
    end

    describe "#resolve_version" do
      it "just returns the version" do
        expect(NetFetcher.resolve_version("1.2.3", source)).to eq("1.2.3")
      end
    end
  end
end
