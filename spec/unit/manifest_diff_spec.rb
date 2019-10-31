require "spec_helper"

module Omnibus
  describe ManifestDiff do
    def manifest_entry_for(name, dv, lv)
      Omnibus::ManifestEntry.new(name, { described_version: dv,
                                         locked_version: lv,
                                         locked_source: {
                                     git: "git://#{name}@example.com" },
                                         source_type: :git,
                                 })
    end

    let(:manifest_one) do
      m = Omnibus::Manifest.new
      m.add("foo", manifest_entry_for("foo", "1.2.4", "deadbeef"))
      m.add("bar", manifest_entry_for("bar", "1.2.4", "deadbeef"))
      m.add("baz", manifest_entry_for("baz", "1.2.4", "deadbeef"))
      m
    end

    let(:manifest_two) do
      m = Omnibus::Manifest.new
      m.add("foo", manifest_entry_for("foo", "1.2.5", "deadbea0"))
      m.add("baz", manifest_entry_for("baz", "1.2.4", "deadbeef"))
      m.add("quux", manifest_entry_for("quux", "1.2.4", "deadbeef"))
      m
    end

    subject { described_class.new(manifest_one, manifest_two) }

    describe "#updated" do
      it "returns items that existed in the first manifest but have been changed" do
        expect(subject.updated).to eq([{ name: "foo",
                                         old_version: "deadbeef",
                                         new_version: "deadbea0",
                                         source_type: :git,
                                         source: { git: "git://foo@example.com" },
                                       }])
      end

      describe "#removed" do
        it "returns items that existed in the first manfiest but don't exist in the second" do
          expect(subject.removed).to eq([{ name: "bar",
                                           old_version: "deadbeef",
                                           source_type: :git,
                                           source: { git: "git://bar@example.com" },
                                         }])
        end
      end

      describe "#added" do
        it "returns items that did not exist in the first manifest but do exist in the second" do
          expect(subject.added).to eq([{ name: "quux",
                                         new_version: "deadbeef",
                                         source_type: :git,
                                         source: { git: "git://quux@example.com" },
                                       }])
        end
      end

      describe "#empty?" do
        it "returns false if there have been changes" do
          expect(subject.empty?).to eq(false)
        end

        it "returns true if nothing changed" do
          diff = Omnibus::ManifestDiff.new(manifest_one, manifest_one)
          expect(diff.empty?).to eq(true)
        end
      end
    end
  end
end
