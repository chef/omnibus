require "spec_helper"

module Omnibus
  describe Config do
    subject { described_class.instance }

    it "extends Util" do
      expect(subject).to be_a(Util)
    end

    before do
      Config.reset!
      # Don't expand paths on the build system. Otherwise, you will end up with
      # paths like +\\Users\\you\\Development\\omnibus-ruby\\C:/omnibus-ruby+
      # when testing on "other" operating systems
      allow(File).to receive(:expand_path) { |arg| arg }
    end

    shared_examples "a configurable" do |id, default|
      it "responds to .#{id}" do
        expect(described_class).to respond_to(id)
      end

      it ".#{id} defaults to #{default.inspect}" do
        expect(described_class.send(id)).to eq(default)
      end

      it_behaves_like "a cleanroom getter", id, default
      it_behaves_like "a cleanroom setter", id, %{#{id}(#{default.inspect})}
    end

    include_examples "a configurable", :base_dir, "/var/cache/omnibus"
    include_examples "a configurable", :cache_dir, "/var/cache/omnibus/cache"
    include_examples "a configurable", :git_cache_dir, "/var/cache/omnibus/cache/git_cache"
    include_examples "a configurable", :source_dir, "/var/cache/omnibus/src"
    include_examples "a configurable", :build_dir, "/var/cache/omnibus/build"
    include_examples "a configurable", :package_dir, "/var/cache/omnibus/pkg"
    include_examples "a configurable", :project_root, Dir.pwd
    include_examples "a configurable", :local_software_dirs, []
    include_examples "a configurable", :software_gems, ["omnibus-software"]
    include_examples "a configurable", :solaris_linker_mapfile, "files/mapfiles/solaris"
    include_examples "a configurable", :append_timestamp, true
    include_examples "a configurable", :build_retries, 0
    include_examples "a configurable", :use_git_caching, true
    include_examples "a configurable", :fetcher_read_timeout, 60
    include_examples "a configurable", :fetcher_retries, 5
    include_examples "a configurable", :fatal_licensing_warnings, false

    describe '#workers' do
      context "when the Ohai data is not present" do
        before do
          stub_ohai(platform: "ubuntu", version: "12.04") do |data|
            data["cpu"] = nil
          end
        end

        it "defaults to 3" do
          expect(described_class.workers).to eq(3)
        end
      end

      context "when the Ohai data is present" do
        before do
          stub_ohai(platform: "ubuntu", version: "12.04") do |data|
            data["cpu"] = { "total" => "5" }
          end
        end

        it "defaults to the value + 6" do
          expect(described_class.workers).to eq(6)
        end
      end
    end

    context "on Windows" do
      before { stub_ohai(platform: "windows", version: "2012") }

      include_examples "a configurable", :base_dir, "C:/omnibus-ruby"
      include_examples "a configurable", :cache_dir, "C:/omnibus-ruby/cache"
      include_examples "a configurable", :git_cache_dir, "C:/omnibus-ruby/cache/git_cache"
      include_examples "a configurable", :source_dir, "C:/omnibus-ruby/src"
      include_examples "a configurable", :build_dir, "C:/omnibus-ruby/build"
      include_examples "a configurable", :package_dir, "C:/omnibus-ruby/pkg"
    end

    context "when base_dir is changed" do
      before { described_class.base_dir("/foo/bar") }

      include_examples "a configurable", :cache_dir, "/foo/bar/cache"
      include_examples "a configurable", :git_cache_dir, "/foo/bar/cache/git_cache"
      include_examples "a configurable", :source_dir, "/foo/bar/src"
      include_examples "a configurable", :build_dir, "/foo/bar/build"
      include_examples "a configurable", :package_dir, "/foo/bar/pkg"
    end
  end
end
