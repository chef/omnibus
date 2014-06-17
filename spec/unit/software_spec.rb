require 'spec_helper'

describe Omnibus::Software do
  let(:project) do
    double(Omnibus::Project, install_path: '/monkeys', overrides: {})
  end

  let(:software_name) { 'erchef' }
  let(:software_file) { software_path(software_name) }

  let(:software) do
    Omnibus::Software.load(software_file, project)
  end

  before do
    allow_any_instance_of(Omnibus::Software).to receive(:render_tasks)
    stub_ohai(platform: 'linux')
  end

  describe "with_standard_compiler_flags helper" do
    context "on ubuntu" do
      before do
        stub_ohai(platform: 'ubuntu')
      end
      it "should set the defaults" do
        expect(software.with_standard_compiler_flags).to eq("LDFLAGS"=>"-Wl,-rpath,/monkeys/embedded/lib -L/monkeys/embedded/lib", "CFLAGS"=>"-I/monkeys/embedded/include")
      end
      it "should override LDFLAGS" do
        expect(software.with_standard_compiler_flags("LDFLAGS"=>"foo")).to eq("LDFLAGS"=>"-Wl,-rpath,/monkeys/embedded/lib -L/monkeys/embedded/lib", "CFLAGS"=>"-I/monkeys/embedded/include")
      end
      it "should override CFLAGS" do
        expect(software.with_standard_compiler_flags("CFLAGS"=>"foo")).to eq("LDFLAGS"=>"-Wl,-rpath,/monkeys/embedded/lib -L/monkeys/embedded/lib", "CFLAGS"=>"-I/monkeys/embedded/include")
      end
      it "should preserve anything else" do
        expect(software.with_standard_compiler_flags("numberwang"=>4)).to eq("numberwang"=>4,"LDFLAGS"=>"-Wl,-rpath,/monkeys/embedded/lib -L/monkeys/embedded/lib", "CFLAGS"=>"-I/monkeys/embedded/include")
      end
    end
    context "on solaris2" do
      before do
        stub_ohai(platform: 'solaris2')
      end
      it "should set the defaults" do
        expect(software.with_standard_compiler_flags).to eq("LDFLAGS"=>"-R/monkeys/embedded/lib -L/monkeys/embedded/lib -static-libgcc", "CFLAGS"=>"-I/monkeys/embedded/include")
      end
    end
    context "on mac_os_x" do
      before do
        stub_ohai(platform: 'mac_os_x')
      end
      it "should set the defaults" do
        expect(software.with_standard_compiler_flags).to eq("LDFLAGS"=>"-L/monkeys/embedded/lib", "CFLAGS"=>"-I/monkeys/embedded/include")
      end
    end
  end

  describe "path helpers" do
    before do
      stub_const("File::PATH_SEPARATOR", separator)
      ENV.stub(:[]).and_call_original
      ENV.stub(:[]).with("PATH").and_return(path)
    end

    context "on *NIX" do
      let(:separator) { ":" }
      let(:path) { "/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin" }

      it "prepends a path to PATH" do
        expect(software.prepend_path("/foo/bar")).to eq("/foo/bar:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin")
      end

      it "prepends the embedded bin to PATH" do
        expect(software.with_embedded_path).to eq("PATH" => "/monkeys/bin:/monkeys/embedded/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin")
      end

      it "with_embedded_path merges with a hash argument" do
        expect(software.with_embedded_path("numberwang" => 4)).to eq("numberwang" => 4, "PATH" => "/monkeys/bin:/monkeys/embedded/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin")
      end

      it "prepends multiple paths to PATH" do
        expect(software.prepend_path("/foo/bar", "/foo/baz"))
          .to eq("/foo/bar:/foo/baz:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin")
      end
    end

    context "on Windows" do
      before do
        stub_ohai(platform: 'windows')
        project.stub(:install_path).and_return("c:/monkeys")
        ENV.stub(:[]).with("Path").and_return(windows_path)
      end

      let(:separator) { ";" }
      let(:path) { "c:/Ruby193/bin;c:/Windows/system32;c:/Windows;c:/Windows/System32/Wbem" }
      let(:windows_path) { "c:/Ruby999/bin;c:/Windows/system32;c:/Windows;c:/Windows/System32/Wbem" }

      it "prepends a path to PATH" do
        expect(software.prepend_path("c:/foo/bar")).to eq("c:/foo/bar;c:/Ruby999/bin;c:/Windows/system32;c:/Windows;c:/Windows/System32/Wbem")
      end

      it "prepends the embedded bin to PATH" do
        expect(software.with_embedded_path).to eq("Path" => "c:/monkeys/bin;c:/monkeys/embedded/bin;c:/Ruby999/bin;c:/Windows/system32;c:/Windows;c:/Windows/System32/Wbem")
      end

      it "with_embedded_path merges with a hash argument" do
        expect(software.with_embedded_path("numberwang" => 4)).to eq("numberwang" => 4, "Path" => "c:/monkeys/bin;c:/monkeys/embedded/bin;c:/Ruby999/bin;c:/Windows/system32;c:/Windows;c:/Windows/System32/Wbem")
      end

      it "prepends multiple paths to PATH" do
        expect(software.prepend_path("c:/foo/bar", "c:/foo/baz"))
          .to eq("c:/foo/bar;c:/foo/baz;c:/Ruby999/bin;c:/Windows/system32;c:/Windows;c:/Windows/System32/Wbem")
      end
    end
  end

  describe '#<=>' do
    it 'compares projects by name' do
      list = [
        Omnibus::Software.load(software_path('zlib'), project),
        Omnibus::Software.load(software_path('erchef'), project),
      ]
      expect(list.sort.map(&:name)).to eq(%w(erchef zlib))
    end
  end

  describe '#whitelist_file' do
    it 'appends to the whitelist_files array' do
      expect(software.whitelist_files.size).to eq(0)
      software.whitelist_file(/foo\/bar/)
      expect(software.whitelist_files.size).to eq(1)
    end

    it 'converts Strings to Regexp instances' do
      software.whitelist_file 'foo/bar'
      expect(software.whitelist_files.size).to eq(1)
      expect(software.whitelist_files.first).to be_kind_of(Regexp)
    end
  end

  describe '#override_version' do
    it 'returns the override version' do
      software.stub(:overrides).and_return(version: '1.2.3')
      expect(software.override_version).to eq('1.2.3')
    end

    it 'outputs a deprecation message' do
      output = capture_logging { software.override_version }
      expect(output).to include('DEPRECATED')
    end
  end

  describe '#given_version' do
    it 'returns the version' do
      software.stub(:default_version).and_return('4.5.6')
      expect(software.given_version).to eq('4.5.6')
    end

    it 'outputs a deprecation message' do
      output = capture_logging { software.given_version }
      expect(output).to include('DEPRECATED')
    end
  end

  describe '#version' do
    it 'sets the given version' do
      software.version('1.2.3')
      expect(software.given_version).to eq('1.2.3')
    end

    it 'outputs a deprecation message' do
      output = capture_logging { software.version('1.2.3') }
      expect(output).to include('DEPRECATED')
    end
  end

  context 'testing repo-level version overrides' do
    let(:software_name) { 'zlib' }
    let(:default_version) { '1.2.6' }
    let(:expected_version) { '1.2.6' }
    let(:expected_override_version) { nil }
    let(:expected_md5) { '618e944d7c7cd6521551e30b32322f4a' }
    let(:expected_url) { 'http://downloads.sourceforge.net/project/libpng/zlib/1.2.6/zlib-1.2.6.tar.gz' }

    shared_examples_for 'a software definition' do
      it 'should have the same name' do
        expect(software.name).to eq(software_name)
      end

      it 'should have the same version' do
        expect(software.version).to eq(expected_version)
      end

      it 'should have the right default_version' do
        expect(software.default_version).to eq(default_version)
      end

      it 'should have nil for an override_version' do
        expect(software.override_version).to eq(expected_override_version)
      end

      it 'should have the right source md5' do
        expect(software.source[:md5]).to eq(expected_md5)
      end

      it 'should have the right source url' do
        expect(software.source[:url]).to eq(expected_url)
      end

      it 'should have the right checksum' do
        expect(software.checksum).to eq(expected_md5)
      end

      it 'should have the right source_uri' do
        expect(software.source_uri).to eq(URI.parse(expected_url))
      end
    end

    context 'without overrides' do
      it_behaves_like 'a software definition'
    end

    context 'with overrides for different software' do
      let(:overrides) { { 'chaos_monkey' => '1.2.8' } }
      let(:software) { Omnibus::Software.load(software_file, project, overrides) }

      it_behaves_like 'a software definition'
    end

    context 'with overrides for this software' do
      let(:expected_version) { '1.2.8' }
      let(:expected_override_version) { '1.2.8' }
      let(:overrides) { { software_name => expected_override_version } }
      let(:software) { Omnibus::Software.load(software_file, project, overrides) }
      let(:expected_md5) { '44d667c142d7cda120332623eab69f40' }
      let(:expected_url) { 'http://downloads.sourceforge.net/project/libpng/zlib/1.2.8/zlib-1.2.8.tar.gz' }

      it_behaves_like 'a software definition'
    end

    context 'with an overide in the project' do
      let(:project) do
        double(Omnibus::Project, install_path: 'monkeys', overrides: { zlib: { version: '1.2.8' } })
      end
      let(:expected_version) { '1.2.8' }
      let(:expected_override_version) { '1.2.8' }
      let(:expected_md5) { '44d667c142d7cda120332623eab69f40' }
      let(:expected_url) { 'http://downloads.sourceforge.net/project/libpng/zlib/1.2.8/zlib-1.2.8.tar.gz' }

      it_behaves_like 'a software definition'

      context 'with the source overridden' do
        let(:expected_md5) { '1234567890' }
        let(:expected_url) { 'http://foo.bar/zlib-1.2.8.tar.gz' }
        let(:project) do
          double(Omnibus::Project, install_path: 'monkeys', overrides: { zlib: { version: '1.2.8', source: { url: expected_url, md5: expected_md5 } } })
        end

        it_behaves_like 'a software definition'
      end
    end
  end

  context 'while getting version_for_cache' do
    let(:fetcher) { nil }
    let(:software_name) { 'zlib' }
    let(:default_version) { '1.2.6' }

    def get_version_for_cache(expected_version)
      software.stub(:fetcher).and_return(fetcher)
      expect(software.version_for_cache).to eq(expected_version)
    end

    context 'without a fetcher' do
      it 'should return the default version' do
        get_version_for_cache('1.2.6')
      end
    end

    context 'with a NetFetcher' do
      let(:fetcher) { Omnibus::NetFetcher.new(software) }

      it 'should return the default version' do
        get_version_for_cache('1.2.6')
      end
    end

    context 'with a GitFetcher' do
      let(:fetcher) do
        a = Omnibus::GitFetcher.new(software)
        a.stub(:target_revision).and_return('4b19a96d57bff9bbf4764d7323b92a0944009b9e')
        a
      end

      it 'should return the git sha' do
        get_version_for_cache('4b19a96d57bff9bbf4764d7323b92a0944009b9e')
      end
    end
  end
end
