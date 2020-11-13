require "omnibus"
require "spec_helper"

describe Omnibus do
  before do
    allow(File).to receive(:directory?).and_return(true)

    allow(Gem::Specification).to receive(:find_all_by_name)
      .with("omnibus-software")
      .and_return([double(gem_dir: File.join(tmp_path, "/gem/omnibus-software"))])

    allow(Gem::Specification).to receive(:find_all_by_name)
      .with("custom-omnibus-software")
      .and_return([double(gem_dir: File.join(tmp_path, "/gem/custom-omnibus-software"))])

    Omnibus::Config.project_root(File.join(tmp_path, "/foo/bar"))
    Omnibus::Config.local_software_dirs([File.join(tmp_path, "/local"), File.join(tmp_path, "/other")])
    Omnibus::Config.software_gems(%w{omnibus-software custom-omnibus-software})
  end

  describe "#which" do
    it "returns nil when the file does not exist" do
      stub_env("PATH", nil)
      expect(subject.which("not_a_real_executable")).to be nil
    end

    it "returns the path when the file exists" do

      ruby_cmd = windows? ? "ruby.exe" : "ruby"
      ruby = Bundler.which(ruby_cmd)
      expect(subject.which(ruby)).to eq(ruby)
      expect(subject.which(ruby_cmd)).to eq(ruby)
    end
  end

  describe "#project_path" do
    before do
      allow(Omnibus).to receive(:project_map)
        .and_return("chef" => "/projects/chef")
    end

    it "accepts a string" do
      expect(subject.project_path("chef")).to eq("/projects/chef")
    end

    it "accepts a symbol" do
      expect(subject.project_path(:chef)).to eq("/projects/chef")
    end

    it "returns nil when the project does not exist" do
      expect(subject.project_path("bacon")).to be nil
    end
  end

  describe "#software_path" do
    before do
      allow(Omnibus).to receive(:software_map)
        .and_return("chef" => "/software/chef")
    end

    it "accepts a string" do
      expect(subject.software_path("chef")).to eq("/software/chef")
    end

    it "accepts a symbol" do
      expect(subject.software_path(:chef)).to eq("/software/chef")
    end

    it "returns nil when the project does not exist" do
      expect(subject.software_path("bacon")).to be nil
    end
  end

  describe "#possible_paths_for" do
    it "searches all paths" do
      expect(subject.possible_paths_for("file")).to eq(%w{
        /foo/bar/file
        /local/file
        /other/file
        /gem/omnibus-software/file
        /gem/custom-omnibus-software/file
      }.map { |path| File.join(tmp_path, path) })
    end
  end
end
