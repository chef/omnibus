require "spec_helper"
require "omnibus/manifest"
require "omnibus/manifest_entry"

module Omnibus
  describe Manifest do
    subject { described_class.new }

    describe "#add" do
      it "stores manifest entries" do
        me = ManifestEntry.new("womabt", {})
        expect { subject.add("wombat", me) }.to_not raise_error
      end

      it "raises an error if it isn't given a ManifestEntry" do
        expect { subject.add("foobar", {}) }.to raise_error Manifest::NotAManifestEntry
      end
    end

    describe "#entry_for" do
      it "returns a ManifestEntry for the requested software" do
        me = ManifestEntry.new("foobar", {})
        subject.add("foobar", me)
        expect(subject.entry_for(:foobar)).to eq(me)
      end

      it "raises an error if no such manifest entry exists" do
        expect { subject.entry_for("non-existant-entry") }.to raise_error Manifest::MissingManifestEntry
      end
    end

    describe "#each" do
      it "yields each item to the block" do
        first  = ManifestEntry.new("foobar", {})
        second = ManifestEntry.new("wombat", {})
        subject.add("foobar", first)
        subject.add("wombat", second)
        expect { |b| subject.each(&b) }.to yield_successive_args(first, second)
      end
    end

    describe "#entry_names" do
      it "returns an array of software names present in the manifest" do
        first  = ManifestEntry.new("foobar", {})
        second = ManifestEntry.new("wombat", {})
        subject.add("foobar", first)
        subject.add("wombat", second)
        expect(subject.entry_names).to eq([:foobar, :wombat])
      end
    end

    describe "#to_hash" do
      it "returns a Hash containg the current manifest format" do
        expect(subject.to_hash[:manifest_format]).to eq(Manifest::LATEST_MANIFEST_FORMAT)
      end

      it "includes entries for software in the manifest" do
        subject.add("foobar", ManifestEntry.new("foobar", {}))
        expect(subject.to_hash[:software]).to have_key(:foobar)
      end

      it "converts the manifest entries to hashes" do
        subject.add("foobar", ManifestEntry.new("foobar", {}))
        expect(subject.to_hash[:software][:foobar]).to be_a(Hash)
      end

      it "returns a build_version if one was passed in" do
        expect(Omnibus::Manifest.new("1.2.3").to_hash[:build_version]).to eq("1.2.3")
      end

      it "returns a build_git_revision if one was passed in" do
        expect(Omnibus::Manifest.new("1.2.3", "e8e8e8").to_hash[:build_git_revision]).to eq("e8e8e8")
      end

      it "returns a license if one was passed in" do
        expect(Omnibus::Manifest.new("1.2.3", "e8e8e8", "Apache").to_hash[:license]).to eq("Apache")
      end
    end

    describe "#from_hash" do
      let(:manifest) {
        { manifest_format: 1,
          build_version: "12.4.0+20150629082811",
          build_git_revision: "2e763ac957b308ba95cef256c2491a5a55a163cc",
          software: {
            zlib: {
              locked_source: {
                url: "an_url",
              },
              locked_version: "new.newer",
              source_type: "url",
              described_version: "new.newer",
            },
          },
        }
      }

      it "has a build_version" do
        expect(Manifest.from_hash(manifest).build_version).to eq("12.4.0+20150629082811")
      end

      it "has a build_git_revision" do
        expect(Manifest.from_hash(manifest).build_git_revision).to eq("2e763ac957b308ba95cef256c2491a5a55a163cc")
      end

      it "returns a manifest from a hash" do
        expect(Manifest.from_hash(manifest)).to be_a(Manifest)
      end

      it "normalizes the source to use symbols" do
        expect(Manifest.from_hash(manifest).entry_for(:zlib).locked_source).to eq({ url: "an_url" })
      end

      context "v2 manifest" do
        let(:manifest) {
          { manifest_format: 2,
            build_version: "12.4.0+20150629082811",
            build_git_revision: "2e763ac957b308ba95cef256c2491a5a55a163cc",
            license: "Unspecified",
            software: {
              zlib: {
                locked_source: {
                  url: "an_url",
                },
                locked_version: "new.newer",
                source_type: "url",
                described_version: "new.newer",
                license: "Zlib",
              },
            },
          }
        }

        it "has a license" do
          expect(Manifest.from_hash(manifest).license).to eq("Unspecified")
        end
      end

      context "unsupported manifest" do
        let(:manifest) {
          {
            manifest_format: 99,
          }
        }

        it "raises an error if it doesn't recognize the manifest version" do
          expect { Manifest.from_hash(manifest) }.to raise_error Manifest::InvalidManifestFormat
        end
      end
    end
  end
end
