require "spec_helper"

module Omnibus
  describe GitFetcher do
    let(:source_path) { "/local/path" }
    let(:project_dir) { "/project/dir" }
    let(:build_dir) { "/build/dir" }

    let(:manifest_entry) do
      double(ManifestEntry,
        name: "software",
        locked_version: "123abcd1234",
        described_version: "some-git-ref",
        locked_source: { path: source_path })
    end

    subject { described_class.new(manifest_entry, project_dir, build_dir) }

    describe '#fetch_required?' do

      context "when the repository is not cloned" do
        before { allow(subject).to receive(:cloned?).and_return(false) }

        it "returns true" do
          expect(subject.fetch_required?).to be_truthy
        end
      end

      context "when the repository is cloned" do
        before { allow(subject).to receive(:cloned?).and_return(true) }
        before { allow(subject).to receive(:resolved_version).and_return("12341235") }
        context "when the revision is not in the repo" do
          before { allow(subject).to receive(:contains_revision?).and_return(false) }

          it "returns true" do
            expect(subject.fetch_required?).to be_truthy
          end
        end

        context "when the revision is present in the repo" do
          before { allow(subject).to receive(:contains_revision?).and_return(true) }

          it "returns false" do
            expect(subject.fetch_required?).to be(false)
          end
        end
      end
    end

    describe '#version_guid' do
      let(:revision) { "abcd1234" }

      before do
        allow(subject).to receive(:current_revision).and_return(revision)
      end

      it "returns the revision" do
        expect(subject.version_guid).to eq("git:#{revision}")
      end
    end

    describe '#clean' do
      before do
        allow(subject).to receive(:git)
        allow(subject).to receive(:resolved_version).and_return("12341235")
      end

      it "checks out the working directory at the correct revision" do
        expect(subject).to receive(:git_checkout)
        subject.clean
      end

      it "cleans the directory" do
        expect(subject).to receive(:git).with("clean -fdx")
        subject.clean
      end

      it "returns true" do
        expect(subject.clean).to be_truthy
      end
    end

    describe '#fetch' do
      before do
        allow(subject).to receive(:create_required_directories)
      end

      context "when the repository is cloned" do
        before { allow(subject).to receive(:cloned?).and_return(true) }

        it "fetches the resolved_version" do
          expect(subject).to receive(:git_fetch)
          subject.fetch
        end
      end

      context "when the repository is not cloned" do
        before do
          allow(subject).to receive(:cloned?).and_return(false)
          allow(subject).to receive(:dir_empty?).and_return(true)
          allow(subject).to receive(:git_clone)
        end

        context "but a directory does exist" do
          before { expect(subject).to receive(:dir_empty?).with(project_dir).and_return(false) }

          it "forcefully removes and recreates the directory" do
            expect(FileUtils).to receive(:rm_rf).with(project_dir).and_return(project_dir)
            expect(Dir).to receive(:mkdir).with(project_dir).and_return(0)
            subject.fetch
          end
        end

        it "clones the repository and checks out the correct revision" do
          expect(subject).to receive(:git_clone).once
          subject.fetch
        end
      end
    end

    describe '#version_for_cache' do
      it "returns the shasum of the commit that we expect to be at" do
        expect(subject.version_for_cache).to eq("revision:123abcd1234")
      end
    end
  end
end
