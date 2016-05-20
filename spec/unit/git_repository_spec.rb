require "spec_helper"

module Omnibus
  describe GitRepository do
    let(:git_repo) do
      path = local_git_repo("foobar", annotated_tags: ["1.0", "2.0", "3.0"])
      Omnibus::GitRepository.new(path)
    end

    describe "#authors" do
      it "returns an array of authors between two tags" do
        expect(git_repo.authors("1.0", "2.0")).to eq(["omnibus"])
      end

      it "returns an empty array if start_ref == end_ref" do
        expect(git_repo.authors("3.0", "3.0")).to eq([])
      end

      it "doesn't return duplicates" do
        expect(git_repo.authors("1.0", "3.0")).to eq(["omnibus"])
      end

      it "returns an error if the tags don't exist" do
        expect { git_repo.authors("1.0", "WUT") }.to raise_error(RuntimeError)
      end
    end

    describe "#latest_tag" do
      it "returns the latest annotated tag" do
        expect(git_repo.latest_tag).to eq("3.0")
      end
    end

    describe "#revision" do
      it "returns the current revision at HEAD" do
        expect(git_repo.revision).to eq("632501dde2c41f3bdd988b818b4c008e2ff398dc")
      end
    end

    describe "#file_at_revision" do
      it "returns the text of the specified file in a repository at a given revision" do
        expect(git_repo.file_at_revision("configure", "1.0")).to eq("echo \"Done!\"")
      end
    end

    describe "#commit_messages" do
      it "returns the raw text from commits between two tags as an array of lines" do
        expect(git_repo.commit_messages("1.0", "3.0")).to eq(["Create tag 3.0\n", "\n", "Create tag 2.0\n"])
      end

      it "returns lines with the newline attached" do
        expect(git_repo.commit_messages("1.0", "3.0").first[-1]).to eq("\n")
      end

      it "returns an empty array if start_ref == end_ref" do
        expect(git_repo.commit_messages("3.0", "3.0")).to eq([])
      end
    end
  end
end
