require "spec_helper"
require "omnibus/manifest_entry"

module Omnibus
  describe GitFetcher do
    include_examples "a software"

    let(:remote)  { remote_git_repo("zlib") }
    let(:version) { "master" }

    let(:source) do
      { git: remote }
    end

    let(:manifest_entry) do
      double(ManifestEntry,
        name: "software",
        locked_version: "45ded6d3b1a35d66ed866b2c3eb418426e6382b0",
        described_version: version,
        locked_source: source)
    end

    subject { described_class.new(manifest_entry, project_dir, build_dir) }

    let(:revision) { shellout!("git rev-parse HEAD", cwd: project_dir).stdout.strip }

    describe "#fetch_required?" do
      context "when the repo is not cloned" do
        it "return true" do
          expect(subject.fetch_required?).to be_truthy
        end
      end

      context "when the repo is cloned" do
        before { subject.fetch }

        context "when the revision is not available" do
          let(:manifest_entry) do
            double(ManifestEntry,
              name: "software",
              locked_version: "abcdefabcdef5d66ed866b2c3eb418426e6382b0",
              described_version: version,
              locked_source: source)
          end

          it "return true" do
            expect(subject.fetch_required?).to be_truthy
          end
        end

        context "when the revisions are the same" do
          it "return false" do
            expect(subject.fetch_required?).to be(false)
          end
        end
      end
    end

    describe "#version_guid" do
      it "includes the current revision" do
        expect(subject.version_guid).to match(/^git:[0-9a-f]{40}/)
      end
    end

    describe "#clean" do
      before do
        subject.fetch
      end

      it "returns true" do
        expect(subject.clean).to be_truthy
      end

      context "when the project directory has extra files in it" do
        it "cleans the git repo" do
          create_file("#{project_dir}/file_a")
          create_file("#{project_dir}/.file_b")
          subject.clean
          expect("#{project_dir}/file_a").to_not be_a_file
          expect("#{project_dir}/.file_b").to_not be_a_file
        end
      end

      context "when the project directory is at a different version" do
        before do
          # Dirty the project_dir by giving it a conflicting commit.
          create_file("#{project_dir}/file_a") { "some new file" }
          create_file("#{project_dir}/configure") { "LALALALA" }
          shellout!("git add .", cwd: project_dir)
          shellout!('git commit -am "Some commit"', cwd: project_dir)
          create_file("#{project_dir}/.file_b")
        end

        it "checks out the right version" do
          subject.clean
          expect(revision).to eq(manifest_entry.locked_version)
        end

        it "resets the working tree" do
          subject.clean
          expect("#{project_dir}/file_a").to_not be_a_file
          expect("#{project_dir}/.file_b").to_not be_a_file
          expect(File.read("#{project_dir}/configure")).to_not match("LA")
        end
      end
    end

    describe "#fetch"  do
      let(:version)  { "v1.2.4" }
      let(:remote)   { remote_git_repo("zlib", annotated_tags: [version]) }
      let(:manifest_entry) do
        double(ManifestEntry,
          name: "software",
          locked_version: "efde208366abd0f91419d8a54b45e3f6e0540105",
          described_version: version,
          locked_source: source)
      end

      subject { described_class.new(manifest_entry, project_dir, build_dir) }

      it "clones the repository" do
        subject.fetch
        expect("#{project_dir}/.git").to be_a_directory
      end
    end

    describe "#resolve_version" do
      context "when the version is a tag" do
        let(:version)  { "v1.2.3" }
        let(:remote)   { remote_git_repo("zlib", tags: [version]) }

        it "parses the tag" do
          expect(GitFetcher.resolve_version(version, source)).to eq("53c72c4abcc961b153996f5b5f402ce715e47146")
        end
      end

      context "when the version is an annnotated tag" do
        let(:version)  { "v1.2.4" }
        let(:remote)   { remote_git_repo("zlib", annotated_tags: [version]) }

        it "it defererences and parses the annotated tag" do
          expect(GitFetcher.resolve_version(version, source)).to eq("efde208366abd0f91419d8a54b45e3f6e0540105")
        end
      end

      context "when the version is a branch" do
        let(:version) { "sethvargo/magic_ponies" }
        let(:remote)  { remote_git_repo("zlib", branches: [version]) }

        it "parses the branch" do
          expect(GitFetcher.resolve_version(version, source)).to eq("171a1aec35ac0a050f8dccd9c9ef4609b1d8d8ea")
        end
      end

      context "when the version is a full SHA-1" do
        let(:version) { "45ded6d3b1a35d66ed866b2c3eb418426e6382b0" }
        let(:remote)  { remote_git_repo("zlib") }

        it "parses the full SHA-1" do
          expect(GitFetcher.resolve_version(version, source)).to eq("45ded6d3b1a35d66ed866b2c3eb418426e6382b0")
        end
      end

      context "when the version is a abbreviated SHA-1" do
        let(:version) { "45ded6d" }
        let(:remote)  { remote_git_repo("zlib") }

        it "parses the abbreviated SHA-1" do
          expect(GitFetcher.resolve_version(version, source)).to eq("45ded6d")
        end
      end

      context "when the version is a non-existent ref" do
        let(:version) { "fufufufufu" }
        let(:remote)  { remote_git_repo("zlib") }

        it "raise an exception" do
          expect { GitFetcher.resolve_version(version, source) }.to raise_error(UnresolvableGitReference)
        end
      end
    end

    describe "#version_for_cache" do
      it "includes the resolved revision" do
        expect(subject.version_for_cache).to eq("revision:45ded6d3b1a35d66ed866b2c3eb418426e6382b0")
      end

      it "not use the current version on disk after fetching" do
        expect(subject.version_for_cache).to eq("revision:45ded6d3b1a35d66ed866b2c3eb418426e6382b0")
        subject.fetch
        expect(subject.version_for_cache).to eq("revision:45ded6d3b1a35d66ed866b2c3eb418426e6382b0")
        expect(revision).to_not eq("revision:45ded6d3b1a35d66ed866b2c3eb418426e6382b0")
      end
    end
  end
end
