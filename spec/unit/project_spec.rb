require "spec_helper"
require "ohai"

module Omnibus
  describe Project do
    subject do
      described_class.new.evaluate do
        name "sample"
        friendly_name "Sample Project"
        install_dir "/sample"
        maintainer "Sample Devs"
        homepage "http://example.com/"

        build_version "1.0"
        build_iteration 1

        extra_package_file "/path/to/sample_dir"
        extra_package_file "/path/to/file.conf"

        resources_path "sample/project/resources"
      end
    end

    it_behaves_like "a cleanroom setter", :name, %{name 'chef'}
    it_behaves_like "a cleanroom setter", :friendly_name, %{friendly_name 'Chef'}
    it_behaves_like "a cleanroom setter", :package_name, %{package_name 'chef.package'}
    it_behaves_like "a cleanroom setter", :maintainer, %{maintainer 'Chef Software, Inc'}
    it_behaves_like "a cleanroom setter", :homepage, %{homepage 'https://getchef.com'}
    it_behaves_like "a cleanroom setter", :description, %{description 'Installs the thing'}
    it_behaves_like "a cleanroom setter", :replace, %{replace 'old-chef'}
    it_behaves_like "a cleanroom setter", :provide, %{provide 'chefy-package'}
    it_behaves_like "a cleanroom setter", :conflict, %{conflict 'puppet'}
    it_behaves_like "a cleanroom setter", :build_version, %{build_version '1.2.3'}
    it_behaves_like "a cleanroom setter", :build_iteration, %{build_iteration 1}
    it_behaves_like "a cleanroom setter", :package_user, %{package_user 'chef'}
    it_behaves_like "a cleanroom setter", :package_group, %{package_group 'chef'}
    it_behaves_like "a cleanroom setter", :override, %{override :chefdk, source: 'foo.com'}
    it_behaves_like "a cleanroom setter", :resources_path, %{resources_path '/path'}
    it_behaves_like "a cleanroom setter", :package_scripts_path, %{package_scripts_path '/path/scripts'}
    it_behaves_like "a cleanroom setter", :dependency, %{dependency 'libxslt-dev'}
    it_behaves_like "a cleanroom setter", :runtime_dependency, %{runtime_dependency 'libxslt'}
    it_behaves_like "a cleanroom setter", :exclude, %{exclude 'hamlet'}
    it_behaves_like "a cleanroom setter", :config_file, %{config_file '/path/to/config.rb'}
    it_behaves_like "a cleanroom setter", :extra_package_file, %{extra_package_file '/path/to/asset'}
    it_behaves_like "a cleanroom setter", :text_manifest_path, %{text_manifest_path '/path/to/manifest.txt'}
    it_behaves_like "a cleanroom setter", :json_manifest_path, %{json_manifest_path '/path/to/manifest.txt'}
    it_behaves_like "a cleanroom setter", :build_git_revision, %{build_git_revision 'wombats'}
    it_behaves_like "a cleanroom getter", :files_path
    it_behaves_like "a cleanroom setter", :license, %{license 'Apache 2.0'}
    it_behaves_like "a cleanroom setter", :license_file, %{license_file 'LICENSES/artistic.txt'}
    it_behaves_like "a cleanroom setter", :license_file_path, %{license_file_path 'CHEF_LICENSE'}

    describe "basics" do
      it "returns a name" do
        expect(subject.name).to eq("sample")
      end

      it "returns an install_dir" do
        expect(subject.install_dir).to eq("/sample")
      end

      it "returns a maintainer" do
        expect(subject.maintainer).to eq("Sample Devs")
      end

      it "returns a homepage" do
        expect(subject.homepage).to eq("http://example.com/")
      end

      it "returns a build version" do
        expect(subject.build_version).to eq("1.0")
      end

      it "returns a build iteration" do
        expect(subject.build_iteration).to eq(1)
      end

      it "returns an array of files and dirs" do
        expect(subject.extra_package_files).to eq(["/path/to/sample_dir", "/path/to/file.conf"])
      end

      it "returns a friendly_name" do
        expect(subject.friendly_name).to eq("Sample Project")
      end

      it "returns a resources_path" do
        expect(subject.resources_path).to include("sample/project/resources")
      end
    end

    describe "#install_dir" do
      it "removes duplicate slashes" do
        subject.install_dir("///opt//chef")
        expect(subject.install_dir).to eq("/opt/chef")
      end

      it "converts Windows slashes to Ruby ones" do
        subject.install_dir('C:\\chef\\chefdk')
        expect(subject.install_dir).to eq("C:/chef/chefdk")
      end

      it "removes trailing slashes" do
        subject.install_dir("/opt/chef//")
        expect(subject.install_dir).to eq("/opt/chef")
      end

      it "is a DSL method" do
        expect(subject).to have_exposed_method(:install_dir)
      end
    end

    describe "#default_root" do
      context "on Windows" do
        before { stub_ohai(platform: "windows", version: "2012") }

        it "returns C:/" do
          expect(subject.default_root).to eq("C:")
        end
      end

      context "on non-Windows" do
        before { stub_ohai(platform: "ubuntu", version: "12.04") }

        it "returns /opt" do
          expect(subject.default_root).to eq("/opt")
        end
      end

      it "is a DSL method" do
        expect(subject).to have_exposed_method(:default_root)
      end
    end

    describe "build_git_revision" do
      let(:git_repo_subdir_path) do
        path = local_git_repo("foobar", annotated_tags: ["1.0", "2.0", "3.0"])
        subdir_path = File.join(path, "asubdir")
        Dir.mkdir(subdir_path)
        subdir_path
      end

      it "returns a revision even when running in a subdir" do
        Dir.chdir(git_repo_subdir_path) do
          expect(subject.build_git_revision).to eq("632501dde2c41f3bdd988b818b4c008e2ff398dc")
        end
      end
    end

    describe "#license" do
      it "sets the default to Unspecified" do
        expect(subject.license).to eq ("Unspecified")
      end
    end

    describe "#license_file_path" do
      it "sets the default to LICENSE" do
        expect(subject.license_file_path).to eq ("/sample/LICENSE")
      end
    end

    describe "#dirty!" do
      let(:software) { double(Omnibus::Software) }

      it "dirties the cache" do
        subject.instance_variable_set(:@culprit, nil)
        subject.dirty!(software)
        expect(subject).to be_dirty
      end

      it "sets the culprit" do
        subject.instance_variable_set(:@culprit, nil)
        subject.dirty!(software)
        expect(subject.culprit).to be(software)
      end
    end

    describe "#dirty?" do
      it "returns true by default" do
        subject.instance_variable_set(:@culprit, nil)
        expect(subject).to_not be_dirty
      end

      it "returns true when the cache is dirty" do
        subject.instance_variable_set(:@culprit, true)
        expect(subject).to be_dirty
      end

      it "returns false when the cache is not dirty" do
        subject.instance_variable_set(:@culprit, false)
        expect(subject).to_not be_dirty
      end
    end

    describe "#<=>" do
      let(:chefdk) { described_class.new.tap { |p| p.name("chefdk") } }
      let(:chef)   { described_class.new.tap { |p| p.name("chef") } }
      let(:ruby)   { described_class.new.tap { |p| p.name("ruby") } }

      it "compares projects by name" do
        list = [chefdk, chef, ruby]
        expect(list.sort.map(&:name)).to eq(%w{chef chefdk ruby})
      end
    end

    describe "#build_iteration" do
      let(:fauxhai_options) { Hash.new }

      before { stub_ohai(fauxhai_options) }

      context "when on RHEL" do
        let(:fauxhai_options) { { platform: "redhat", version: "6.4" } }
        it "returns a RHEL iteration" do
          expect(subject.build_iteration).to eq(1)
        end
      end

      context "when on Debian" do
        let(:fauxhai_options) { { platform: "debian", version: "7.2" } }
        it "returns a Debian iteration" do
          expect(subject.build_iteration).to eq(1)
        end
      end

      context "when on FreeBSD" do
        let(:fauxhai_options) { { platform: "freebsd", version: "9.1" } }
        it "returns a FreeBSD iteration" do
          expect(subject.build_iteration).to eq(1)
        end
      end

      context "when on Windows" do
        before { stub_ohai(platform: "windows", version: "2008R2") }
        before { stub_const("File::ALT_SEPARATOR", '\\') }
        it "returns a Windows iteration" do
          expect(subject.build_iteration).to eq(1)
        end
      end

      context "when on OS X" do
        let(:fauxhai_options) { { platform: "mac_os_x", version: "10.8.2" } }
        it "returns a generic iteration" do
          expect(subject.build_iteration).to eq(1)
        end
      end
    end

    describe "#overrides" do
      before { subject.overrides.clear }

      it "sets all the things through #overrides" do
        subject.override(:thing, version: "6.6.6")
        expect(subject.override(:zlib)).to be_nil
      end

      it "retrieves the things set through #overrides" do
        subject.override(:thing, version: "6.6.6")
        expect(subject.override(:thing)[:version]).to eq("6.6.6")
      end

      it "symbolizes #overrides" do
        subject.override("thing", version: "6.6.6")
        [:thing, "thing"].each do |thing|
          expect(subject.override(thing)).not_to be_nil
        end
        expect(subject.override(:thing)[:version]).to eq("6.6.6")
      end
    end

    describe "#ohai" do
      before { stub_ohai(platform: "ubuntu", version: "12.04") }

      it "is a DSL method" do
        expect(subject).to have_exposed_method(:ohai)
      end

      it "delegates to the Ohai class" do
        expect(subject.ohai).to be(Ohai)
      end
    end

    describe "#packagers_for_system" do
      it "returns array of packager objects" do
        subject.packagers_for_system.each do |packager|
          expect(packager).to be_a(Packager::Base)
        end
      end

      it "calls Packager#for_current_system" do
        expect(Packager).to receive(:for_current_system)
          .and_call_original
        subject.packagers_for_system
      end
    end

    describe "#package" do
      it "raises an exception when a block is not given" do
        expect { subject.package(:foo) }.to raise_error(InvalidValue)
      end

      it "adds the block to the list" do
        block = Proc.new {}
        subject.package(:foo, &block)

        expect(subject.packagers[:foo]).to include(block)
      end

      it "allows for multiple invocations, keeping order" do
        block_1, block_2 = Proc.new {}, Proc.new {}
        subject.package(:foo, &block_1)
        subject.package(:foo, &block_2)

        expect(subject.packagers[:foo]).to eq([block_1, block_2])
      end
    end

    describe "#packagers" do
      it "returns a Hash" do
        expect(subject.packagers).to be_a(Hash)
      end

      it "has a default Hash value of an empty array" do
        expect(subject.packagers[:foo]).to be_a(Array)
        expect(subject.packagers[:bar]).to_not be(subject.packagers[:foo])
      end
    end

    describe "#compressor" do
      it "returns a compressor object" do
        expect(subject.compressor).to be_a(Compressor::Base)
      end

      it "calls Compressor#for_current_system" do
        expect(Compressor).to receive(:for_current_system)
          .and_call_original

        subject.compressor
      end

      it "passes in the current compressors" do
        subject.compress(:dmg)
        subject.compress(:tgz)

        expect(Compressor).to receive(:for_current_system)
          .with([:dmg, :tgz])
          .and_call_original

        subject.compressor
      end
    end

    describe "#compress" do
      it "does not raises an exception when a block is not given" do
        expect { subject.compress(:foo) }.to_not raise_error
      end

      it "adds the compressor to the list" do
        subject.compress(:foo)
        expect(subject.compressors).to include(:foo)
      end

      it "adds the block to the list" do
        block = Proc.new {}
        subject.compress(:foo, &block)

        expect(subject.compressors[:foo]).to include(block)
      end

      it "allows for multiple invocations, keeping order" do
        block_1, block_2 = Proc.new {}, Proc.new {}
        subject.compress(:foo, &block_1)
        subject.compress(:foo, &block_2)

        expect(subject.compressors[:foo]).to eq([block_1, block_2])
      end
    end

    describe "#compressors" do
      it "returns a Hash" do
        expect(subject.compressors).to be_a(Hash)
      end

      it "has a default Hash value of an empty array" do
        expect(subject.compressors[:foo]).to be_a(Array)
        expect(subject.compressors[:bar]).to_not be(subject.compressors[:foo])
      end
    end

    describe "#shasum" do
      context "when a filepath is given" do
        let(:path) { "/project.rb" }
        let(:file) { double(File) }

        before do
          subject.instance_variable_set(:@filepath, path)

          allow(File).to receive(:exist?)
            .with(path)
            .and_return(true)
          allow(File).to receive(:open)
            .with(path)
            .and_return(file)
        end

        it "returns the correct shasum" do
          expect(subject.shasum).to eq("2cb8bdd11c766caa11a37607e84ffb51af3ae3da16931988f12f7fc9de98d68e")
        end
      end

      context "when a filepath is not given" do
        before { subject.send(:remove_instance_variable, :@filepath) }

        it "returns the correct shasum" do
          expect(subject.shasum).to eq("3cc6bd98da4d643b79c71be2c93761a458b442e2931f7d421636f526d0c1e8bf")
        end
      end
    end
  end
end
