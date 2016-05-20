require "spec_helper"
require "omnibus/manifest_entry"

module Omnibus
  describe Fetcher do
    let(:source_path) { "/local/path" }
    let(:project_dir) { "/project/dir" }
    let(:build_dir) { "/build/dir" }

    let(:manifest_entry) do
      double(Software,
        name: "software",
        locked_version: "31aedfs",
        described_version: "mrfancypants",
        locked_source: { path: source_path })
    end

    subject { described_class.new(manifest_entry, project_dir, build_dir) }

    describe "#initialize" do
      it "sets the resovled_version to the locked_version" do
        expect(subject.resolved_version).to eq("31aedfs")
      end

      it "sets the source to the locked_source" do
        expect(subject.source).to eq({ path: source_path })
      end

      it "sets the described_version to the described version" do
        expect(subject.described_version).to eq("mrfancypants")
      end
    end
  end
end
