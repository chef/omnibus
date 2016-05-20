require "spec_helper"

module Omnibus
  describe PathFetcher do
    include_examples "a software"

    let(:source_path) { File.join(tmp_path, "remote", "software") }

    let(:source) do
      { path: source_path }
    end

    let(:manifest_entry) do
      double(Omnibus::ManifestEntry,
             name: "pathelogical",
             locked_version: nil,
             described_version: nil,
             locked_source: source)
    end

    before do
      create_directory(source_path)
    end

    subject { described_class.new(manifest_entry, project_dir, build_dir) }

    describe '#fetch_required?' do
      context "when the directories have different files" do
        before do
          create_file("#{source_path}/directory/file") { "different" }
          create_file("#{project_dir}/directory/file") { "same" }
        end

        it "return true" do
          expect(subject.fetch_required?).to be_truthy
        end
      end

      context "when the directories have the same files" do
        before do
          create_file("#{source_path}/directory/file") { "same" }
          create_file("#{project_dir}/directory/file") { "same" }
        end

        it "returns false" do
          expect(subject.fetch_required?).to be(false)
        end
      end
    end

    describe '#version_guid' do
      it "includes the source path" do
        expect(subject.version_guid).to eq("path:#{source_path}")
      end
    end

    describe "#fetch" do
      before do
        create_file("#{source_path}/file_a")
        create_file("#{source_path}/file_b")
        create_file("#{source_path}/.file_c")
        remove_file("#{source_path}/file_d")

        create_file("#{project_dir}/file_a")
        remove_file("#{project_dir}/file_b")
        remove_file("#{project_dir}/.file_c")
        create_file("#{project_dir}/file_d")
      end

      it "fetches new files" do
        subject.fetch

        expect("#{project_dir}/file_a").to be_a_file
        expect("#{project_dir}/file_b").to be_a_file
        expect("#{project_dir}/.file_c").to be_a_file
      end

      it "removes extraneous files" do
        subject.fetch

        expect("#{project_dir}/file_d").to_not be_a_file
      end
    end

    describe '#clean' do
      it "returns true" do
        expect(subject.clean).to be_truthy
      end
    end

    describe '#version_for_cache' do
      before do
        create_file("#{source_path}/file_a")
        create_file("#{source_path}/file_b")
        create_file("#{source_path}/.file_c")
      end

      let(:sha) { "69553b23b84e69e095b4a231877b38022b1ffb41ae0ecbba6bb2625410c49f7e" }

      it "includes the source_path and shasum" do
        expect(subject.version_for_cache).to eq("path:#{source_path}|shasum:#{sha}")
      end
    end

    describe '#resolve_version' do
      it "just returns the version" do
        expect(NetFetcher.resolve_version("1.2.3", source)).to eq("1.2.3")
      end
    end
  end
end
