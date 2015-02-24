require 'spec_helper'
require 'omnibus/manifest'
require 'omnibus/manifest_entry'

module Omnibus
  describe Manifest do
    subject { described_class.new }

    describe "#add" do
      it "stores manifest entries" do
        me = ManifestEntry.new("womabt", {})
        expect {subject.add("wombat", me)}.to_not raise_error
      end

      it "raises an error if it isn't given a ManifestEntry" do
        expect {subject.add("foobar", {})}.to raise_error Manifest::NotAManifestEntry
      end
    end

    describe "#entry_for" do
      it "returns a ManifestEntry for the requested software" do
        me = ManifestEntry.new("foobar", {})
        subject.add("foobar", me)
        expect(subject.entry_for("foobar")).to eq(me)
      end

      it "raises an error if no such manifest entry exists" do
        expect {subject.entry_for("non-existant-entry")}.to raise_error Manifest::MissingManifestEntry
      end
    end

    describe "#to_hash" do
      it "returns a Hash containg the current manifest format" do
        expect(subject.to_hash['manifest_format']).to eq(Manifest::LATEST_MANIFEST_FORMAT)
      end

      it "includes entries for software in the manifest" do
        subject.add("foobar", ManifestEntry.new("foobar", {}))
        expect(subject.to_hash['software']).to have_key("foobar")
      end

      it "converts the manifest entries to hashes" do
        subject.add("foobar", ManifestEntry.new("foobar", {}))
        expect(subject.to_hash['software']['foobar']).to be_a(Hash)
      end
    end

    describe "#from_hash" do
      let(:manifest) {
        { "manifest_format" => 1,
          "software" => {
            "zlib" => {
              "locked_source" => {
                "url" => "an_url"
              },
              "locked_version" => "new.newer",
              "source_type" => "url",
              "described_version" => "new.newer"}}}
      }

      let(:v2_manifest) {
        {"manifest_format" => 2}
      }

      it "returns a manifest from a hash" do
        expect(Manifest.from_hash(manifest)).to be_a(Manifest)
      end

      it "normalizes the source to use symbols" do
        expect(Manifest.from_hash(manifest).entry_for("zlib").locked_source).to eq({:url => "an_url"})
      end

      it "raises an error if it doesn't recognize the manifest version" do
        expect{Manifest.from_hash(v2_manifest)}.to raise_error Manifest::InvalidManifestFormat
      end
    end
  end
end
