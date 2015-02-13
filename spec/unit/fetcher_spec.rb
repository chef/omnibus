require 'spec_helper'
require 'omnibus/manifest_entry'

module Omnibus
  describe Fetcher do
        let(:source_path) { '/local/path' }
    let(:project_dir) { '/project/dir' }
    let(:build_dir) { '/build/dir' }

    let(:software) do
      double(Software,
        name: 'software',
        version: 'master',
        source: { path: source_path },
        project_dir: project_dir,
        build_dir: project_dir,
      )
    end

    subject { described_class.new(software) }


    describe "#use_manifest_entry" do
      let(:source) {{:git => "git://git.example.com/important/stuff"}}
      let(:version) { 'efde208366abd0f91419d8a54b45e3f6e0540105' }
      let(:manifest_entry) {
        Omnibus::ManifestEntry.new("zlib",
                                   { :locked_version => version,
                                     :locked_source => source})

      }

      it "sets the resovled_version to the locked_version" do
        subject.use_manifest_entry(manifest_entry)
        expect(subject.resolved_version).to eq(version)
      end

      it "sets the source to the locked_source" do
        subject.use_manifest_entry(manifest_entry)
        expect(subject.source).to eq(source)
      end
    end
  end
end
