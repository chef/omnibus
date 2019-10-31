require "spec_helper"
require "omnibus/changelog_printer"
require "omnibus/manifest_diff"

module Omnibus
  describe ChangeLogPrinter do
    describe "#print" do
      def manifest_entry_for(name, dv, lv, source_type = :local)
        Omnibus::ManifestEntry.new(name, { described_version: dv,
                                           locked_version: lv,
                                           locked_source: {
                                             git: "git://#{name}@example.com" },
                                           source_type: source_type,
        })
      end

      let(:changelog) do
        double(ChangeLog,
          changelog_entries: %w{entry1 entry2},
          authors: %w{alice bob})
      end
      let(:git_changelog) do
        double(ChangeLog,
          changelog_entries:
          %w{sub-entry1 sub-entry2})
      end
      let(:now) { double(Time) }
      let(:emptydiff) { EmptyManifestDiff.new }
      let(:old_manifest) do
        m = Manifest.new
        m.add("updated-comp", manifest_entry_for("updated-comp", "v9", "v9"))
        m.add("updated-comp-2", manifest_entry_for("updated-comp-2", "someref0", "someref0", :git))
        m.add("removed-comp", manifest_entry_for("removed-comp", "v9", "v9"))
        m.add("removed-comp-2", manifest_entry_for("removed-comp-2", "v10", "v10"))
        m
      end
      let(:new_manifest) do
        m = Manifest.new
        m.add("updated-comp", manifest_entry_for("updated-comp", "v10", "v10"))
        m.add("updated-comp-2", manifest_entry_for("updated-comp-2", "someotherref", "someotherref", :git))
        m.add("added-comp", manifest_entry_for("added-comp", "v100", "v100"))
        m.add("added-comp-2", manifest_entry_for("added-comp-2", "v101", "v101"))
        m
      end
      let(:diff) { ManifestDiff.new(old_manifest, new_manifest) }

      it "starts with a changelog version header including the time" do
        expect(Time).to receive(:now).and_return(now)
        expect(now).to receive(:strftime).with("%Y-%m-%d")
          .and_return("1970-01-01")

        expect { ChangeLogPrinter.new(changelog, diff).print("v1.0.1") }
          .to output(/## v1\.0\.1 \(1970-01-01\)/).to_stdout
      end

      it "outputs the list of changelog entries" do
        [ /entry1/, /entry2/ ].each do |re|
          expect { ChangeLogPrinter.new(changelog, diff).print("v1") }
            .to output(re).to_stdout
        end
      end

      it "outputs the component sections when there are changes" do
        expect { ChangeLogPrinter.new(changelog, diff).print("v1") }
          .to output(/### Components/).to_stdout
      end

      it "does not output a component sections when there are no changes" do
        expect { ChangeLogPrinter.new(changelog, emptydiff).print("v1") }
          .not_to output(/### Components/).to_stdout
      end

      it "outputs the list of new components" do
        [
          /New Components/,
          /added-comp \(v100\)/,
          /added-comp-2 \(v101\)/,
        ].each do |re|
          expect { ChangeLogPrinter.new(changelog, diff).print("v1") }
            .to output(re).to_stdout
        end
      end

      it "outputs the list of updated components" do
        source_path = "path/to/source/"
        allow(File).to receive(:directory?).with("#{source_path}updated-comp-2/.git")
          .and_return(false)

        [ /Updated Components/,
          /updated-comp \(v9 -> v10\)/,
          /updated-comp-2 \(someref0 -> someothe\)/,
        ].each do |re|
          expect { ChangeLogPrinter.new(changelog, diff, source_path).print("v1") }
            .to output(re).to_stdout
        end
      end

      it "uses git commit log for components in git repositories" do
        git_repo = double(GitRepository)
        source_path = "path/to/source/"
        allow(File).to receive(:directory?).with("#{source_path}updated-comp-2/.git")
          .and_return(true)
        allow(GitRepository).to receive(:new).with("#{source_path}updated-comp-2")
          .and_return(git_repo)
        allow(ChangeLog).to receive(:new).with("someref0", "someotherref", git_repo)
          .and_return(git_changelog)

        [ /  \* sub-entry1/,
          /  \* sub-entry2/,
        ].each do |re|
          expect { ChangeLogPrinter.new(changelog, diff, source_path).print("v1") }
            .to output(re).to_stdout
        end
      end

      it "outputs the list of removed components" do
        [ /Removed Components/,
          /removed-comp \(v9\)/,
          /removed-comp-2 \(v10\)/,
        ].each do |re|
          expect { ChangeLogPrinter.new(changelog, diff).print("v1") }
            .to output(re).to_stdout
        end
      end

      it "outputs the list of contributors" do
        [ /### Contributors/, /alice/, /bob/ ].each do |re|
          expect { ChangeLogPrinter.new(changelog, diff).print("v1") }
            .to output(re).to_stdout
        end
      end
    end
  end
end
