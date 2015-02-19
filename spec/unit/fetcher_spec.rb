require 'spec_helper'
require 'omnibus/manifest_entry'

module Omnibus
  describe Fetcher do
        let(:source_path) { '/local/path' }
    let(:project_dir) { '/project/dir' }
    let(:build_dir) { '/build/dir' }

    let(:manifest_entry) do
      double(Software,
        name: 'software',
        locked_version: '31aedfs',
        locked_source: { path: source_path })
    end

    subject { described_class.new(manifest_entry, project_dir, build_dir) }


    describe "#initialize" do
      it "sets the resovled_version to the locked_version" do
        expect(subject.resolved_version).to eq("31aedfs")
      end

      it "sets the source to the locked_source" do
        expect(subject.source).to eq({ path: source_path})
      end
    end
  end
end
