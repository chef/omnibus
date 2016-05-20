require "spec_helper"

module Omnibus
  describe ChangeLog do
    describe "#new" do
      it "sets the start_ref to the latest tag if none is set" do
        repo = double(GitRepository, :latest_tag => "1.0")
        expect(ChangeLog.new(nil, "2.0", repo).start_ref).to eq("1.0")
      end

      it "sets the end_ref to HEAD if none is set" do
        expect(ChangeLog.new.end_ref).to eq("HEAD")
      end
    end

    describe "#changelog_entries" do
      it "returns any git log lines with the ChangeLog: tag, removing the tag" do
        repo = double(GitRepository, :commit_messages => ["ChangeLog-Entry: foobar\n",
                                                          "ChangeLog-Entry: wombat\n"])
        changelog = ChangeLog.new("0.0.1", "0.0.2", repo)
        expect(changelog.changelog_entries).to eq(%W{foobar\n wombat\n})
      end

      it "returns an empty array if there were no changelog entries" do
        repo = double(GitRepository, :commit_messages => [])
        changelog = ChangeLog.new("0.0.1", "0.0.2", repo)
        expect(changelog.changelog_entries).to eq([])
      end

      it "does not return git messages without a ChangeLog: tag" do
        repo = double(GitRepository, :commit_messages => %W{foobar\n wombat\n})
        changelog = ChangeLog.new("0.0.1", "0.0.2", repo)
        expect(changelog.changelog_entries).to eq([])
      end

      it "does not return blank lines" do
        repo = double(GitRepository, :commit_messages => %W{\n \n})
        changelog = ChangeLog.new("0.0.1", "0.0.2", repo)
        expect(changelog.changelog_entries).to eq([])
      end

      it "can handle multi-line ChangeLog entries" do
        repo = double(GitRepository, :commit_messages => ["ChangeLog-Entry: foobar\n", "foobaz\n"])
        changelog = ChangeLog.new("0.0.1", "0.0.2", repo)
        expect(changelog.changelog_entries).to eq(["foobar\nfoobaz\n"])
      end

      it "end a ChangeLog entry at the first blank line" do
        repo = double(GitRepository, :commit_messages => ["ChangeLog-Entry: foobar\n", "\n", "foobaz\n"])
        changelog = ChangeLog.new("0.0.1", "0.0.2", repo)
        expect(changelog.changelog_entries).to eq(["foobar\n"])
      end
    end
  end
end
