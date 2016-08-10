require "spec_helper"

module Omnibus
  describe Software do
    let(:project) do
      Project.new.evaluate do
        name "project"
        install_dir "/opt/project"
      end
    end

    let(:source) do
      {
        url: "http://example.com/",
        md5: "abcd1234",
      }
    end

    let(:rel_path) { "software" }

    subject do
      local_source = source
      local_rel_path = rel_path

      described_class.new(project).evaluate do
        name "software"
        default_version "1.2.3"

        source local_source
        relative_path local_rel_path
      end
    end

    it_behaves_like "a cleanroom getter", :project
    it_behaves_like "a cleanroom setter", :name, %{name 'libxml2'}
    it_behaves_like "a cleanroom setter", :description, %{description 'The XML magician'}
    it_behaves_like "a cleanroom setter", :maintainer, %{maintainer 'Captain Jack <sparrow@chef.io>'}
    it_behaves_like "a cleanroom setter", :dependency, %{dependency 'libxslt'}
    it_behaves_like "a cleanroom setter", :source, %{source url: 'https://source.example.com'}
    it_behaves_like "a cleanroom setter", :default_version, %{default_version '1.2.3'}
    it_behaves_like "a cleanroom setter", :version, %{version '1.2.3'}
    it_behaves_like "a cleanroom setter", :license, %{license 'Apache 2.0'}
    it_behaves_like "a cleanroom setter", :license_file, %{license_file 'LICENSES/artistic.txt'}
    it_behaves_like "a cleanroom setter", :skip_transitive_dependency_licensing, %{skip_transitive_dependency_licensing true}
    it_behaves_like "a cleanroom setter", :whitelist_file, %{whitelist_file '/opt/whatever'}
    it_behaves_like "a cleanroom setter", :relative_path, %{relative_path '/path/to/extracted'}
    it_behaves_like "a cleanroom setter", :build, %|build {}|
    it_behaves_like "a cleanroom getter", :project_dir
    it_behaves_like "a cleanroom getter", :build_dir
    it_behaves_like "a cleanroom getter", :install_dir
    it_behaves_like "a cleanroom getter", :with_standard_compiler_flags
    it_behaves_like "a cleanroom setter", :with_embedded_path, %|with_embedded_path({ 'foo' => 'bar' })|
    it_behaves_like "a cleanroom setter", :prepend_path, %|prepend_path({ 'foo' => 'bar' })|

    context "when a source_uri is present" do
      let(:uri) { URI.parse("http://example.com/foo.tar.gz") }
      before { allow(subject).to receive(:source_uri).and_return(uri) }

      it_behaves_like "a cleanroom getter", :project_file
    end

    context "when no license is present" do
      it "sets the defaults" do
        expect(subject.license).to eq ("Unspecified")
      end
    end

    describe "with_standard_compiler_flags helper" do
      context "on ubuntu" do
        before { stub_ohai(platform: "ubuntu", version: "12.04") }

        it "sets the defaults" do
          expect(subject.with_standard_compiler_flags).to eq(
            "LDFLAGS"         => "-Wl,-rpath,/opt/project/embedded/lib -L/opt/project/embedded/lib",
            "CFLAGS"          => "-I/opt/project/embedded/include -O2",
            "CXXFLAGS"        => "-I/opt/project/embedded/include -O2",
            "CPPFLAGS"        => "-I/opt/project/embedded/include -O2",
            "LD_RUN_PATH"     => "/opt/project/embedded/lib",
            "PKG_CONFIG_PATH" => "/opt/project/embedded/lib/pkgconfig"
          )
        end
        it "overrides LDFLAGS" do
          expect(subject.with_standard_compiler_flags("LDFLAGS" => "foo")).to eq(
            "LDFLAGS"         => "-Wl,-rpath,/opt/project/embedded/lib -L/opt/project/embedded/lib",
            "CFLAGS"          => "-I/opt/project/embedded/include -O2",
            "CXXFLAGS"        => "-I/opt/project/embedded/include -O2",
            "CPPFLAGS"        => "-I/opt/project/embedded/include -O2",
            "LD_RUN_PATH"     => "/opt/project/embedded/lib",
            "PKG_CONFIG_PATH" => "/opt/project/embedded/lib/pkgconfig"
          )
        end
        it "overrides CFLAGS" do
          expect(subject.with_standard_compiler_flags("CFLAGS" => "foo")).to eq(
            "LDFLAGS"         => "-Wl,-rpath,/opt/project/embedded/lib -L/opt/project/embedded/lib",
            "CFLAGS"          => "-I/opt/project/embedded/include -O2",
            "CXXFLAGS"        => "-I/opt/project/embedded/include -O2",
            "CPPFLAGS"        => "-I/opt/project/embedded/include -O2",
            "LD_RUN_PATH"     => "/opt/project/embedded/lib",
            "PKG_CONFIG_PATH" => "/opt/project/embedded/lib/pkgconfig"
          )
        end
        it "overrides CXXFLAGS" do
          expect(subject.with_standard_compiler_flags("CXXFLAGS" => "foo")).to eq(
            "LDFLAGS"         => "-Wl,-rpath,/opt/project/embedded/lib -L/opt/project/embedded/lib",
            "CFLAGS"          => "-I/opt/project/embedded/include -O2",
            "CXXFLAGS"        => "-I/opt/project/embedded/include -O2",
            "CPPFLAGS"        => "-I/opt/project/embedded/include -O2",
            "LD_RUN_PATH"     => "/opt/project/embedded/lib",
            "PKG_CONFIG_PATH" => "/opt/project/embedded/lib/pkgconfig"
          )
        end
        it "overrides CPPFLAGS" do
          expect(subject.with_standard_compiler_flags("CPPFLAGS" => "foo")).to eq(
            "LDFLAGS"         => "-Wl,-rpath,/opt/project/embedded/lib -L/opt/project/embedded/lib",
            "CFLAGS"          => "-I/opt/project/embedded/include -O2",
            "CXXFLAGS"        => "-I/opt/project/embedded/include -O2",
            "CPPFLAGS"        => "-I/opt/project/embedded/include -O2",
            "LD_RUN_PATH"     => "/opt/project/embedded/lib",
            "PKG_CONFIG_PATH" => "/opt/project/embedded/lib/pkgconfig"
          )
        end
        it "preserves anything else" do
          expect(subject.with_standard_compiler_flags("numberwang" => 4)).to eq(
            "numberwang"      => 4,
            "LDFLAGS"         => "-Wl,-rpath,/opt/project/embedded/lib -L/opt/project/embedded/lib",
            "CFLAGS"          => "-I/opt/project/embedded/include -O2",
            "CXXFLAGS"        => "-I/opt/project/embedded/include -O2",
            "CPPFLAGS"        => "-I/opt/project/embedded/include -O2",
            "LD_RUN_PATH"     => "/opt/project/embedded/lib",
            "PKG_CONFIG_PATH" => "/opt/project/embedded/lib/pkgconfig"
          )
        end
      end

      context "on solaris_11" do
        before do
          stub_ohai(platform: "solaris2", version: "5.11") do |data|
            # For some reason, this isn't set in Fauxhai
            data["platform"] = "solaris2"
          end
        end

        it "sets the defaults" do
          expect(subject.with_standard_compiler_flags).to eq(
            "CC"              => "gcc -m64 -static-libgcc",
            "CFLAGS"          => "-I/opt/project/embedded/include -O2",
            "CPPFLAGS"        => "-I/opt/project/embedded/include -O2",
            "CXXFLAGS"        => "-I/opt/project/embedded/include -O2",
            "LDFLAGS"         => "-Wl,-rpath,/opt/project/embedded/lib -L/opt/project/embedded/lib -static-libgcc",
            "LD_OPTIONS"      => "-R/opt/project/embedded/lib",
            "LD_RUN_PATH"     => "/opt/project/embedded/lib",
            "PKG_CONFIG_PATH" => "/opt/project/embedded/lib/pkgconfig"
          )
        end

        context "when loader mapping file is specified" do
          # Let the unit tests run on windows where auto-path translation occurs.
          let(:project_root) { File.join(tmp_path, "/root/project") }
          before do
            stub_ohai(platform: "solaris2", version: "5.11") do |data|
              # For some reason, this isn't set in Fauxhai
              data["platform"] = "solaris2"
            end
            Config.project_root(project_root)
            Config.solaris_linker_mapfile("files/mapfile/solaris")
            allow(File).to receive(:exist?).and_return(true)
          end

          it "sets LD_OPTIONS correctly" do
            expect(subject.with_standard_compiler_flags).to eq(
              "CC"              => "gcc -m64 -static-libgcc",
              "CFLAGS"          => "-I/opt/project/embedded/include -O2",
              "CPPFLAGS"        => "-I/opt/project/embedded/include -O2",
              "CXXFLAGS"        => "-I/opt/project/embedded/include -O2",
              "LDFLAGS"         => "-Wl,-rpath,/opt/project/embedded/lib -L/opt/project/embedded/lib -static-libgcc",
              "LD_OPTIONS"      => "-R/opt/project/embedded/lib",
              "LD_RUN_PATH"     => "/opt/project/embedded/lib",
              "PKG_CONFIG_PATH" => "/opt/project/embedded/lib/pkgconfig"
            )
          end
        end
      end

      context "on solaris_10" do
        before do
          stub_ohai(platform: "solaris2", version: "5.10") do |data|
            # For some reason, this isn't set in Fauxhai
            data["platform"] = "solaris2"
          end
        end

        it "sets the defaults" do
          expect(subject.with_standard_compiler_flags).to eq(
            "CC"              => "gcc -static-libgcc",
            "LDFLAGS"         => "-R/opt/project/embedded/lib -L/opt/project/embedded/lib -static-libgcc",
            "CFLAGS"          => "-I/opt/project/embedded/include",
            "CXXFLAGS"        => "-I/opt/project/embedded/include",
            "CPPFLAGS"        => "-I/opt/project/embedded/include",
            "LD_RUN_PATH"     => "/opt/project/embedded/lib",
            "LD_OPTIONS"      => "-R/opt/project/embedded/lib",
            "PKG_CONFIG_PATH" => "/opt/project/embedded/lib/pkgconfig"
          )
        end

        context "when loader mapping file is specified" do
          # Let the unit tests run on windows where auto-path translation occurs.
          let(:project_root) { File.join(tmp_path, "/root/project") }
          before do
            stub_ohai(platform: "solaris2", version: "5.10") do |data|
              # For some reason, this isn't set in Fauxhai
              data["platform"] = "solaris2"
            end
            Config.project_root(project_root)
            Config.solaris_linker_mapfile("files/mapfile/solaris")
            allow(File).to receive(:exist?).and_return(true)
          end

          it "sets LD_OPTIONS correctly" do
            expect(subject.with_standard_compiler_flags).to eq(
              "CC"              => "gcc -static-libgcc",
              "LDFLAGS"         => "-R/opt/project/embedded/lib -L/opt/project/embedded/lib -static-libgcc",
              "CFLAGS"          => "-I/opt/project/embedded/include",
              "CXXFLAGS"        => "-I/opt/project/embedded/include",
              "CPPFLAGS"        => "-I/opt/project/embedded/include",
              "LD_RUN_PATH"     => "/opt/project/embedded/lib",
              "LD_OPTIONS"      => "-R/opt/project/embedded/lib -M #{project_root}/files/mapfile/solaris",
              "PKG_CONFIG_PATH" => "/opt/project/embedded/lib/pkgconfig"
            )
          end
        end
      end

      context "on mac_os_x" do
        before { stub_ohai(platform: "mac_os_x", version: "10.9.2") }

        it "sets the defaults" do
          expect(subject.with_standard_compiler_flags).to eq(
            "LDFLAGS"         => "-L/opt/project/embedded/lib",
            "CFLAGS"          => "-I/opt/project/embedded/include -O2",
            "CXXFLAGS"        => "-I/opt/project/embedded/include -O2",
            "CPPFLAGS"        => "-I/opt/project/embedded/include -O2",
            "LD_RUN_PATH"     => "/opt/project/embedded/lib",
            "PKG_CONFIG_PATH" => "/opt/project/embedded/lib/pkgconfig"
          )
        end
      end

      context "on aix" do
        before do
          # There's no AIX in Fauxhai :(
          stub_ohai(platform: "solaris2", version: "5.11") do |data|
            data["platform"] = "aix"
          end
        end

        it "sets the defaults" do
          expect(subject.with_standard_compiler_flags).to eq(
            "CC"              => "xlc_r -q64",
            "CXX"             => "xlC_r -q64",
            "CFLAGS"          => "-q64 -I/opt/project/embedded/include -D_LARGE_FILES -O",
            "CXXFLAGS"        => "-q64 -I/opt/project/embedded/include -D_LARGE_FILES -O",
            "CPPFLAGS"        => "-q64 -I/opt/project/embedded/include -D_LARGE_FILES -O",
            "LDFLAGS"         => "-q64 -L/opt/project/embedded/lib -Wl,-blibpath:/opt/project/embedded/lib:/usr/lib:/lib",
            "LD"              => "ld -b64",
            "OBJECT_MODE"     => "64",
            "ARFLAGS"         => "-X64 cru",
            "LD_RUN_PATH"     => "/opt/project/embedded/lib",
            "PKG_CONFIG_PATH" => "/opt/project/embedded/lib/pkgconfig"
          )
        end
      end

      context "on freebsd 9" do
        before do
          stub_ohai(platform: "freebsd", version: "9.2")
        end

        it "sets the defaults" do
          expect(subject.with_standard_compiler_flags).to eq(
            "CFLAGS" => "-I/opt/project/embedded/include -O2",
            "CXXFLAGS"  => "-I/opt/project/embedded/include -O2",
            "CPPFLAGS"  => "-I/opt/project/embedded/include -O2",
            "LDFLAGS" => "-L/opt/project/embedded/lib",
            "LD_RUN_PATH" => "/opt/project/embedded/lib",
            "PKG_CONFIG_PATH" => "/opt/project/embedded/lib/pkgconfig"
          )
        end

        context "with gcc 4.9 installed" do
          before do
            allow(subject).to receive(:which).and_return("/usr/local/bin/gcc49")
          end

          it "sets the compiler args" do
            expect(subject.with_standard_compiler_flags).to eq(
              "CC"              => "gcc49",
              "CXX"             => "g++49",
              "CFLAGS" => "-I/opt/project/embedded/include -O2",
              "CXXFLAGS"  => "-I/opt/project/embedded/include -O2",
              "CPPFLAGS"  => "-I/opt/project/embedded/include -O2",
              "LDFLAGS" => "-L/opt/project/embedded/lib",
              "LD_RUN_PATH" => "/opt/project/embedded/lib",
              "PKG_CONFIG_PATH" => "/opt/project/embedded/lib/pkgconfig" )
          end
        end
      end

      context "on freebsd 10" do
        before do
          stub_ohai(platform: "freebsd", version: "10.0")
        end

        it "Clang as the default compiler" do
          expect(subject.with_standard_compiler_flags).to eq(
            "CC"              => "clang",
            "CXX"             => "clang++",
            "CFLAGS"          => "-I/opt/project/embedded/include -O2",
            "CXXFLAGS"        => "-I/opt/project/embedded/include -O2",
            "CPPFLAGS"        => "-I/opt/project/embedded/include -O2",
            "LDFLAGS"         => "-L/opt/project/embedded/lib",
            "LD_RUN_PATH"     => "/opt/project/embedded/lib",
            "PKG_CONFIG_PATH" => "/opt/project/embedded/lib/pkgconfig"
          )
        end
      end

      context "on Windows" do
        let(:win_arch_i386) { true }

        before do
          stub_ohai(platform: "windows", version: "2012")
          allow(subject).to receive(:windows_arch_i386?).and_return(win_arch_i386)
        end

        context "in 32-bit mode" do
          it "sets the default" do
            expect(subject.with_standard_compiler_flags).to eq(
              "CFLAGS"          => "-I/opt/project/embedded/include -m32 -O2 -fno-lto -march=i686",
              "CXXFLAGS"        => "-I/opt/project/embedded/include -m32 -O2 -fno-lto -march=i686",
              "CPPFLAGS"        => "-I/opt/project/embedded/include -m32 -O2 -fno-lto -march=i686",
              "LDFLAGS"         => "-L/opt/project/embedded/lib -m32 -fno-lto",
              "LD_RUN_PATH"     => "/opt/project/embedded/lib",
              "PKG_CONFIG_PATH" => "/opt/project/embedded/lib/pkgconfig"
            )
          end
        end

        context "in 64-bit mode" do
          let(:win_arch_i386) { false }

          it "sets the default" do
            expect(subject.with_standard_compiler_flags).to eq(
              "CFLAGS"          => "-I/opt/project/embedded/include -m64 -O2 -fno-lto -march=x86-64",
              "CXXFLAGS"        => "-I/opt/project/embedded/include -m64 -O2 -fno-lto -march=x86-64",
              "CPPFLAGS"        => "-I/opt/project/embedded/include -m64 -O2 -fno-lto -march=x86-64",
              "LDFLAGS"         => "-L/opt/project/embedded/lib -m64 -fno-lto",
              "LD_RUN_PATH"     => "/opt/project/embedded/lib",
              "PKG_CONFIG_PATH" => "/opt/project/embedded/lib/pkgconfig"
            )
          end
        end
      end

    end

    describe "path helpers" do

      before do
        stub_const("File::PATH_SEPARATOR", separator)
        stub_env("PATH", path)
        allow(project).to receive(:install_dir).and_return(install_dir)
      end

      let(:prepended_path) do
        ["#{install_dir}/bin", separator, "#{install_dir}/embedded/bin", separator, path].join
      end

      context "on *Nix" do
        let(:separator) { ":" }
        let(:path) { "/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin" }
        let(:install_dir) { "/opt/project" }

        it "prepends a path to PATH" do
          expect(subject.prepend_path("/foo/bar")).to eq(
            ["/foo/bar", separator, path].join
          )
        end

        it "prepends the embedded bin to PATH" do
          expect(subject.with_embedded_path).to eq(
            "PATH" => prepended_path
          )
        end

        it "with_embedded_path merges with a hash argument" do
          expect(subject.with_embedded_path("numberwang" => 4)).to eq(
            "numberwang" => 4,
            "PATH" => prepended_path
          )
        end

        it "prepends multiple paths to PATH" do
          expect(subject.prepend_path("/foo/bar", "/foo/baz")).to eq(
            ["/foo/bar", separator, "/foo/baz", separator, path].join
          )
        end
      end

      context "on Windows" do
        before do
          stub_ohai(platform: "windows", version: "2012")
        end

        let(:separator) { ";" }
        let(:path) { "c:/Ruby193/bin;c:/Windows/system32;c:/Windows;c:/Windows/System32/Wbem" }
        let(:install_dir) { "c:/opt/project" }
        let(:prepended_path_msys) do
          [ "#{install_dir}/bin", separator, "#{install_dir}/embedded/bin", separator,
            "#{install_dir}/embedded/msys/1.0/bin", separator, path].join
        end

        context "`Path` exists in the environment" do
          before do
            stub_env("Path", path)
            allow(ENV).to receive(:keys).and_return(%w{ Path PATH })
          end

          it "returns a path key of `Path`" do
            expect(subject.with_embedded_path).to eq(
              "Path" => prepended_path
            )
          end
        end

        context "`Path` does not exist in the environment" do
          before do
            allow(ENV).to receive(:keys).and_return(["PATH"])
          end

          it "returns a path key of `PATH`" do
            expect(subject.with_embedded_path).to eq(
              "PATH" => prepended_path
            )
          end
        end
      end
    end

    describe '#ohai' do
      before { stub_ohai(platform: "ubuntu", version: "12.04") }

      it "is a DSL method" do
        expect(subject).to have_exposed_method(:ohai)
      end

      it "delegates to the Ohai class" do
        expect(subject.ohai).to be(Ohai)
      end
    end

    describe "#manifest_entry" do
      let(:a_source) do
        { url: "http://example.com/",
          md5: "abcd1234" }
      end

      let(:manifest_entry) { Omnibus::ManifestEntry.new("software", { locked_version: "1.2.8", locked_source: a_source }) }
      let(:manifest) do
        m = Omnibus::Manifest.new
        m.add(:software, manifest_entry)
      end

      let(:project_with_manifest) do
        described_class.new(project, nil, manifest).evaluate do
          name "software"
          default_version "1.2.3"
          source url: "http://example.com/",
                 md5: "abcd1234"
        end
      end

      let(:project_without_manifest) do
        described_class.new(project, nil, nil).evaluate do
          name "software"
          default_version "1.2.3"
          source url: "http://example.com/",
                 md5: "abcd1234"
        end
      end

      let(:another_project) do
        described_class.new(project, nil, manifest).evaluate do
          name "ruroh"
        end
      end

      it "constructs a manifest entry if no manifest was provided" do
        expect(project_without_manifest.manifest_entry).to be_a Omnibus::ManifestEntry
        expect(project_without_manifest.manifest_entry.locked_version).to eq("1.2.3")
        expect(project_without_manifest.manifest_entry.locked_source).to eq(a_source)
      end

      it "constructs a manifest entry with a fully resolved version" do
        expect(Omnibus::Fetcher).to receive(:resolve_version).with("1.2.3", a_source).and_return("1.2.8")
        expect(project_without_manifest.manifest_entry.locked_version).to eq("1.2.8")
      end

      it "returns the entry from the user-provided manifest if it was given one" do
        expect(project_with_manifest.manifest_entry).to eq(manifest_entry)
        expect(project_with_manifest.manifest_entry.locked_version).to eq("1.2.8")
        expect(project_with_manifest.manifest_entry.locked_source).to eq(a_source)
      end

      it "raises an error if it was given a manifest but can't find it's entry" do
        expect { another_project.manifest_entry }.to raise_error(Manifest::MissingManifestEntry)
      end
    end

    describe '#<=>' do
      let(:zlib)   { described_class.new(project).tap { |s| s.name("zlib") } }
      let(:erchef) { described_class.new(project).tap { |s| s.name("erchef") } }
      let(:bacon)  { described_class.new(project).tap { |s| s.name("bacon") } }

      it "compares projects by name" do
        list = [zlib, erchef, bacon]
        expect(list.sort.map(&:name)).to eq(%w{bacon erchef zlib})
      end
    end

    describe '#whitelist_file' do
      it "appends to the whitelist_files array" do
        expect(subject.whitelist_files.size).to eq(0)
        subject.whitelist_file(/foo\/bar/)
        expect(subject.whitelist_files.size).to eq(1)
      end

      it "converts Strings to Regexp instances" do
        subject.whitelist_file "foo/bar"
        expect(subject.whitelist_files.size).to eq(1)
        expect(subject.whitelist_files.first).to be_kind_of(Regexp)
      end
    end

    context "testing repo-level version overrides" do
      context "without overrides" do
        it "returns the original values" do
          expect(subject.version).to eq("1.2.3")
          expect(subject.source).to eq(url: "http://example.com/", md5: "abcd1234")
        end
      end

      context "with overrides for different software" do
        before { project.override(:chaos_monkey, version: "1.2.8") }

        it "does not change the software" do
          expect(subject.version).to eq("1.2.3")
        end
      end

      context "with overrides for this software" do
        context "version" do
          let(:version) { "2.0.0.pre" }
          before { project.override(:software, version: "2.0.0.pre") }

          it "returns the correct version" do
            expect(subject.version).to eq(version)
          end
        end

        context "source" do
          let(:source) { { url: "http://new.example.com", md5: "defg5678" } }
          before { project.override(:software, source: source) }

          it "returns the correct source" do
            expect(subject.source).to eq(source)
          end
        end
      end
    end

    context "when software source is a github spec" do
      let(:source) do
        {
          github: "chef/ohai",
        }
      end

      it "fetches from a fully expanded git path" do
        expect(subject.source).to eq(git: "https://github.com/chef/ohai.git")
        expect(Omnibus::Fetcher).to receive(:resolve_version).with("1.2.3", git: "https://github.com/chef/ohai.git").and_return("1.2.8")
        subject.send(:fetcher)
      end

      context "and override source is a git spec" do
        before { project.override(:software, source: { git: "https://blah.com/git.git" }) }

        it "fetches from the override path" do
          expect(subject.source).to eq(git: "https://blah.com/git.git")
          expect(Omnibus::Fetcher).to receive(:resolve_version).with("1.2.3", git: "https://blah.com/git.git").and_return("1.2.8")
          subject.send(:fetcher)
        end
      end

      context "and override source is a github spec" do
        before { project.override(:software, source: { github: "a/b" }) }

        it "fetches from the override path" do
          expect(subject.source).to eq(git: "https://github.com/a/b.git")
          expect(Omnibus::Fetcher).to receive(:resolve_version).with("1.2.3", git: "https://github.com/a/b.git").and_return("1.2.8")
          subject.send(:fetcher)
        end
      end
    end

    context "when software source is a git spec" do
      let(:source) do
        {
          git: "https://blah.com/git.git",
        }
      end

      it "fetches from the git spec" do
        expect(subject.source).to eq(git: "https://blah.com/git.git")
        expect(Omnibus::Fetcher).to receive(:resolve_version).with("1.2.3", git: "https://blah.com/git.git").and_return("1.2.8")
        subject.send(:fetcher)
      end

      context "and override source is a github spec" do
        before { project.override(:software, source: { github: "a/b" }) }

        it "fetches from the override path" do
          expect(subject.source).to eq(git: "https://github.com/a/b.git")
          expect(Omnibus::Fetcher).to receive(:resolve_version).with("1.2.3", git: "https://github.com/a/b.git").and_return("1.2.8")
          subject.send(:fetcher)
        end
      end
    end

    describe '#fetcher' do
      before do
        expect(Omnibus::Fetcher).to receive(:resolve_version).with("1.2.3", source).and_return("1.2.8")
      end

      context "when given a source url to an archive" do
        let(:source) do
          {
            url: "http://example.com/foo.tar.gz",
            md5: "abcd1234",
          }
        end

        context "when relative_path is the same as name" do
          let(:rel_path) { "software" }

          it "ignores back-compat and leaves fetch_dir alone" do
            subject.send(:fetcher)
            expect(subject.project_dir).to eq(File.expand_path("#{Config.source_dir}/software/software"))
          end

          it "sets the fetcher project_dir to fetch_dir" do
            expect(subject.send(:fetcher).project_dir).to eq(File.expand_path("#{Config.source_dir}/software"))
          end
        end

        context "when relative_path is different from name" do
          let(:rel_path) { "foo" }

          it "ignores back-compat and leaves fetch_dir alone" do
            subject.send(:fetcher)
            expect(subject.project_dir).to eq(File.expand_path("#{Config.source_dir}/software/foo"))
          end

          it "sets the fetcher project_dir to fetch_dir" do
            expect(subject.send(:fetcher).project_dir).to eq(File.expand_path("#{Config.source_dir}/software"))
          end
        end
      end

      context "when given source url is not an archive" do
        let(:source) do
          {
            url: "http://example.com/foo.txt",
            md5: "abcd1234",
          }
        end

        context "when relative_path is the same as name" do
          let(:rel_path) { "software" }

          it "for back-compat, changes fetch_dir" do
            subject.send(:fetcher)
            expect(subject.project_dir).to eq(File.expand_path("#{Config.source_dir}/software/software"))
          end

          it "sets the fetcher project_dir to project_dir" do
            expect(subject.send(:fetcher).project_dir).to eq(File.expand_path("#{Config.source_dir}/software/software"))
          end
        end

        context "when relative_path is different from name" do
          let(:rel_path) { "foo" }

          it "ignores back-compat and leaves fetch_dir alone" do
            subject.send(:fetcher)
            expect(subject.project_dir).to eq(File.expand_path("#{Config.source_dir}/software/foo"))
          end

          it "sets the fetcher project_dir to project_dir" do
            expect(subject.send(:fetcher).project_dir).to eq(File.expand_path("#{Config.source_dir}/software/foo"))
          end
        end
      end

      context "when given source is a git repo" do
        let(:source) do
          {
            git: "http://example.com/my/git/repo",
          }
        end

        context "when relative_path is the same as name" do
          let(:rel_path) { "software" }

          it "for back-compat, changes fetch_dir" do
            subject.send(:fetcher)
            expect(subject.project_dir).to eq(File.expand_path("#{Config.source_dir}/software/software"))
          end

          it "sets the fetcher project_dir to project_dir" do
            expect(subject.send(:fetcher).project_dir).to eq(File.expand_path("#{Config.source_dir}/software/software"))
          end
        end

        context "when relative_path is different from name" do
          let(:rel_path) { "foo" }

          it "ignores back-compat and leaves fetch_dir alone" do
            subject.send(:fetcher)
            expect(subject.project_dir).to eq(File.expand_path("#{Config.source_dir}/software/foo"))
          end

          it "sets the fetcher project_dir to project_dir" do
            expect(subject.send(:fetcher).project_dir).to eq(File.expand_path("#{Config.source_dir}/software/foo"))
          end
        end
      end
    end

    describe "#canonicalize_source" do
      it 'canonicalize_source(github: "chef/chef") yields git: "https://github.com/chef/chef.git"' do
        expect(subject.send(:canonicalize_source, github: "chef/chef")).to eq(git: "https://github.com/chef/chef.git")
      end
      it 'canonicalize_source(github: "chef/chef", submodules: true) yields git: "https://github.com/chef/chef.git", submodules: true' do
        expect(subject.send(:canonicalize_source, github: "chef/chef", submodules: true)).to eq(git: "https://github.com/chef/chef.git", submodules: true)
      end
      it "canonicalize_source does not overwrite the original" do
        original = { github: "chef/chef", submodules: true }
        expect(subject.send(:canonicalize_source, original)).to eq(git: "https://github.com/chef/chef.git", submodules: true)
        expect(original).to eq(github: "chef/chef", submodules: true)
      end
    end

    describe '#shasum' do
      context "when a filepath is given" do
        let(:path) { "/software.rb" }
        let(:file) { double(File) }

        before { subject.instance_variable_set(:@filepath, path) }

        before do
          allow(File).to receive(:exist?)
            .with(path)
            .and_return(true)
          allow(File).to receive(:open)
            .with(path)
            .and_return(file)
        end

        it "returns the correct shasum" do
          expect(subject.shasum).to eq("69dcce6da5580abe1da581e3f09d81e13ac676c48790eb0aa44d0ca2f93a16de")
        end
      end

      context "when a filepath is not given" do
        before { subject.send(:remove_instance_variable, :@filepath) }

        it "returns the correct shasum" do
          expect(subject.shasum).to eq("acd88f56f17b7cbc146f351a9265b652bcf96d544821e7bc1e9663c80617276d")
        end
      end
    end
  end
end
