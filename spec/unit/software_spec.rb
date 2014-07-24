require 'spec_helper'

module Omnibus
  describe Software do
    let(:software_name) { 'erchef' }
    let(:software_file) { software_path(software_name) }

    let(:project) {
      project = double(Project,
        name: 'chef',
        install_dir: '/monkeys',
        shasum: 'ABCD1234',
        overrides: {}
      )

      allow(project).to receive(:is_a?)
        .with(Project)
        .and_return(true)

      project
    }

    subject { Software.load(project, software_file) }

    before do
      allow_any_instance_of(Software).to receive(:render_tasks)
    end

    it_behaves_like 'a cleanroom getter', :project
    it_behaves_like 'a cleanroom setter', :name, %|name 'libxml2'|
    it_behaves_like 'a cleanroom setter', :description, %|description 'The XML magician'|
    it_behaves_like 'a cleanroom setter', :always_build, %|always_build true|
    it_behaves_like 'a cleanroom setter', :dependency, %|dependency 'libxslt'|
    it_behaves_like 'a cleanroom setter', :source, %|source url: 'https://source.example.com'|
    it_behaves_like 'a cleanroom setter', :default_version, %|default_version '1.2.3'|
    it_behaves_like 'a cleanroom setter', :version, %|version '1.2.3'|
    it_behaves_like 'a cleanroom setter', :whitelist_file, %|whitelist_file '/opt/whatever'|
    it_behaves_like 'a cleanroom setter', :relative_path, %|relative_path '/path/to/extracted'|
    it_behaves_like 'a cleanroom setter', :build, %|build {}|
    it_behaves_like 'a cleanroom getter', :project_dir
    it_behaves_like 'a cleanroom getter', :build_dir
    it_behaves_like 'a cleanroom getter', :install_dir
    it_behaves_like 'a cleanroom getter', :platform
    it_behaves_like 'a cleanroom getter', :architecture
    it_behaves_like 'a cleanroom getter', :with_standard_compiler_flags
    it_behaves_like 'a cleanroom setter', :with_embedded_path, %|with_embedded_path({ 'foo' => 'bar' })|
    it_behaves_like 'a cleanroom setter', :prepend_path, %|prepend_path({ 'foo' => 'bar' })|
    it_behaves_like 'a cleanroom getter', :source_dir
    it_behaves_like 'a cleanroom getter', :cache_dir
    it_behaves_like 'a cleanroom getter', :config

    context 'when a source_uri is present' do
      let(:uri) { URI.parse('http://example.com/foo.tar.gz') }
      before { allow(subject).to receive(:source_uri).and_return(uri) }

      it_behaves_like 'a cleanroom getter', :downloaded_file
      it_behaves_like 'a cleanroom getter', :project_file
    end

    describe "with_standard_compiler_flags helper" do
      context "on ubuntu" do
        before { stub_ohai(platform: 'ubuntu', version: '12.04') }

        it "sets the defaults" do
          expect(subject.with_standard_compiler_flags).to eq(
            'LDFLAGS'         => '-Wl,-rpath,/monkeys/embedded/lib -L/monkeys/embedded/lib',
            'CFLAGS'          => '-I/monkeys/embedded/include',
            'LD_RUN_PATH'     => '/monkeys/embedded/lib',
            'PKG_CONFIG_PATH' => '/monkeys/embedded/lib/pkgconfig'
          )
        end
        it 'ovesrride LDFLAGS' do
          expect(subject.with_standard_compiler_flags('LDFLAGS'        => 'foo')).to eq(
            'LDFLAGS'         => '-Wl,-rpath,/monkeys/embedded/lib -L/monkeys/embedded/lib',
            'CFLAGS'          => '-I/monkeys/embedded/include',
            'LD_RUN_PATH'     => '/monkeys/embedded/lib',
            'PKG_CONFIG_PATH' => '/monkeys/embedded/lib/pkgconfig'
          )
        end
        it 'ovesrride CFLAGS' do
          expect(subject.with_standard_compiler_flags('CFLAGS'=>'foo')).to eq(
            'LDFLAGS'         => '-Wl,-rpath,/monkeys/embedded/lib -L/monkeys/embedded/lib',
            'CFLAGS'          => '-I/monkeys/embedded/include',
            'LD_RUN_PATH'     => '/monkeys/embedded/lib',
            'PKG_CONFIG_PATH' => '/monkeys/embedded/lib/pkgconfig'
          )
        end
        it 'presserve anything else' do
          expect(subject.with_standard_compiler_flags('numberwang'=>4)).to eq(
            'numberwang'      => 4,
            'LDFLAGS'         => '-Wl,-rpath,/monkeys/embedded/lib -L/monkeys/embedded/lib',
            'CFLAGS'          => '-I/monkeys/embedded/include',
            'LD_RUN_PATH'     => '/monkeys/embedded/lib',
            'PKG_CONFIG_PATH' => '/monkeys/embedded/lib/pkgconfig'
          )
        end
      end

      context 'on solaris2' do
        before do
          stub_ohai(platform: 'solaris2', version: '5.11') do |data|
            # For some reason, this isn't set in Fauxhai
            data['platform'] = 'solaris2'
          end
        end

        it 'sets the defaults' do
          expect(subject.with_standard_compiler_flags).to eq(
            'LDFLAGS'         => '-R/monkeys/embedded/lib -L/monkeys/embedded/lib -static-libgcc',
            'CFLAGS'          => '-I/monkeys/embedded/include',
            'LD_RUN_PATH'     => '/monkeys/embedded/lib',
            'LD_OPTIONS'      => '-R/monkeys/embedded/lib',
            'PKG_CONFIG_PATH' => '/monkeys/embedded/lib/pkgconfig'
          )
        end
      end

      context 'on mac_os_x' do
        before { stub_ohai(platform: 'mac_os_x', version: '10.9.2') }

        it 'sets the defaults' do
          expect(subject.with_standard_compiler_flags).to eq(
            'LDFLAGS'         => '-L/monkeys/embedded/lib',
            'CFLAGS'          => '-I/monkeys/embedded/include',
            'LD_RUN_PATH'     => '/monkeys/embedded/lib',
            'PKG_CONFIG_PATH' => '/monkeys/embedded/lib/pkgconfig'
          )
        end
      end

      context 'on aix' do
        before do
          # There's no AIX in Fauxhai :(
          stub_ohai(platform: 'solaris2', version: '5.11') do |data|
            data['platform'] = 'aix'
          end
        end

        it 'sets the defaults' do
          expect(subject.with_standard_compiler_flags).to eq(
            'CC'              => 'xlc -q64',
            'CXX'             => 'xlC -q64',
            'CFLAGS'          => '-q64 -I/monkeys/embedded/include -O',
            'LDFLAGS'         => '-q64 -L/monkeys/embedded/lib -Wl,-blibpath:/monkeys/embedded/lib:/usr/lib:/lib',
            'LD'              => 'ld -b64',
            'OBJECT_MODE'     => '64',
            'ARFLAGS'         => '-X64 cru',
            'LD_RUN_PATH'     => '/monkeys/embedded/lib',
            'PKG_CONFIG_PATH' => '/monkeys/embedded/lib/pkgconfig'
          )
        end
      end

      context 'on aix with gcc' do
        before do
          # There's no AIX in Fauxhai :(
          stub_ohai(platform: 'solaris2', version: '5.11') do |data|
            data['platform'] = 'aix'
          end
        end

        it 'sets the defaults' do
          expect(subject.with_standard_compiler_flags(nil, aix: { use_gcc: true })).to eq(
            'CC'              => 'gcc -maix64',
            'CXX'             => 'g++ -maix64',
            'CFLAGS'          => '-maix64 -O -I/monkeys/embedded/include',
            'LDFLAGS'         => '-L/monkeys/embedded/lib -Wl,-blibpath:/monkeys/embedded/lib:/usr/lib:/lib',
            'LD'              => 'ld -b64',
            'OBJECT_MODE'     => '64',
            'ARFLAGS'         => '-X64 cru',
            'LD_RUN_PATH'     => '/monkeys/embedded/lib',
            'PKG_CONFIG_PATH' => '/monkeys/embedded/lib/pkgconfig'
          )
        end
      end
    end

    describe 'path helpers' do
      before do
        stub_const('File::PATH_SEPARATOR', separator)
        stub_env('PATH', path)
      end

      context 'on *NIX' do
        let(:separator) { ':' }
        let(:path) { '/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin' }

        it 'prepends a path to PATH' do
          expect(subject.prepend_path('/foo/bar')).to eq(
            '/foo/bar:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin'
          )
        end

        it 'prepends the embedded bin to PATH' do
          expect(subject.with_embedded_path).to eq(
            'PATH' => '/monkeys/bin:/monkeys/embedded/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin'
          )
        end

        it 'with_embedded_path merges with a hash argument' do
          expect(subject.with_embedded_path('numberwang' => 4)).to eq(
            'numberwang' => 4,
            'PATH' => '/monkeys/bin:/monkeys/embedded/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin'
          )
        end

        it 'prepends multiple paths to PATH' do
          expect(subject.prepend_path('/foo/bar', '/foo/baz')).to eq(
            '/foo/bar:/foo/baz:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin'
          )
        end
      end

      context 'on Windows' do
        before do
          stub_ohai(platform: 'windows', version: '2012')
          allow(project).to receive(:install_dir).and_return('c:/monkeys')
          stub_env('Path', windows_path)
        end

        let(:separator) { ';' }
        let(:path) { 'c:/Ruby193/bin;c:/Windows/system32;c:/Windows;c:/Windows/System32/Wbem' }
        let(:windows_path) { 'c:/Ruby999/bin;c:/Windows/system32;c:/Windows;c:/Windows/System32/Wbem' }

        it "prepends a path to PATH" do
          expect(subject.prepend_path('c:/foo/bar')).to eq(
            'c:/foo/bar;c:/Ruby999/bin;c:/Windows/system32;c:/Windows;c:/Windows/System32/Wbem'
          )
        end

        it 'prepends the embedded bin to PATH' do
          expect(subject.with_embedded_path).to eq(
            'Path' => 'c:/monkeys/bin;c:/monkeys/embedded/bin;c:/Ruby999/bin;c:/Windows/system32;c:/Windows;c:/Windows/System32/Wbem'
          )
        end

        it 'with_embedded_path merges with a hash argument' do
          expect(subject.with_embedded_path('numberwang' => 4)).to eq(
            'numberwang' => 4,
            'Path' => 'c:/monkeys/bin;c:/monkeys/embedded/bin;c:/Ruby999/bin;c:/Windows/system32;c:/Windows;c:/Windows/System32/Wbem'
          )
        end

        it 'prepends multiple paths to PATH' do
          expect(subject.prepend_path('c:/foo/bar', 'c:/foo/baz')).to eq(
            'c:/foo/bar;c:/foo/baz;c:/Ruby999/bin;c:/Windows/system32;c:/Windows;c:/Windows/System32/Wbem'
          )
        end
      end
    end

    describe '#<=>' do
      let(:zlib)   { Software.new(project).tap { |s| s.name('zlib') } }
      let(:erchef) { Software.new(project).tap { |s| s.name('erchef') } }
      let(:bacon)  { Software.new(project).tap { |s| s.name('bacon') } }

      it 'compares projects by name' do
        list = [zlib, erchef, bacon]

        expect(list.sort.map(&:name)).to eq(%w(bacon erchef zlib))
      end
    end

    describe '#whitelist_file' do
      it 'appends to the whitelist_files array' do
        expect(subject.whitelist_files.size).to eq(0)
        subject.whitelist_file(/foo\/bar/)
        expect(subject.whitelist_files.size).to eq(1)
      end

      it 'converts Strings to Regexp instances' do
        subject.whitelist_file 'foo/bar'
        expect(subject.whitelist_files.size).to eq(1)
        expect(subject.whitelist_files.first).to be_kind_of(Regexp)
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
          expect(subject.name).to eq(software_name)
        end

        it 'should have the same version' do
          expect(subject.version).to eq(expected_version)
        end

        it 'should have the right default_version' do
          expect(subject.default_version).to eq(default_version)
        end

        it 'should have nil for an override_version' do
          expect(subject.override_version).to eq(expected_override_version)
        end

        it 'should have the right source md5' do
          expect(subject.source[:md5]).to eq(expected_md5)
        end

        it 'should have the right source url' do
          expect(subject.source[:url]).to eq(expected_url)
        end

        it 'should have the right checksum' do
          expect(subject.checksum).to eq(expected_md5)
        end

        it 'should have the right source_uri' do
          expect(subject.source_uri).to eq(URI.parse(expected_url))
        end
      end

      context 'without overrides' do
        it_behaves_like 'a software definition'
      end

      context 'with overrides for different software' do
        let(:overrides) { { 'chaos_monkey' => '1.2.8' } }
        subject { Software.load(project, software_file, overrides) }

        it_behaves_like 'a software definition'
      end

      context 'with overrides for this software' do
        let(:expected_version) { '1.2.8' }
        let(:expected_override_version) { '1.2.8' }
        let(:overrides) { { software_name => expected_override_version } }
        let(:expected_md5) { '44d667c142d7cda120332623eab69f40' }
        let(:expected_url) { 'http://downloads.sourceforge.net/project/libpng/zlib/1.2.8/zlib-1.2.8.tar.gz' }

        subject { Software.load(project, software_file, overrides) }

        it_behaves_like 'a software definition'
      end

      context 'with an overide in the project' do
        let(:expected_version) { '1.2.8' }
        let(:expected_override_version) { '1.2.8' }
        let(:expected_md5) { '44d667c142d7cda120332623eab69f40' }
        let(:expected_url) { 'http://downloads.sourceforge.net/project/libpng/zlib/1.2.8/zlib-1.2.8.tar.gz' }

        before do
          allow(project).to receive(:overrides)
            .and_return(zlib: { version: '1.2.8' })
        end

        it_behaves_like 'a software definition'

        context 'with the source overridden' do
          let(:expected_md5) { '1234567890' }
          let(:expected_url) { 'http://foo.bar/zlib-1.2.8.tar.gz' }

          before do
            allow(project).to receive(:overrides)
              .and_return(zlib: { version: '1.2.8', source: { url: expected_url, md5: expected_md5 } })
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
        subject.instance_variable_set(:@fetcher, fetcher)
        expect(subject.version_for_cache).to eq(expected_version)
      end

      context 'without a fetcher' do
        it 'should return the default version' do
          get_version_for_cache('1.2.6')
        end
      end

      context 'with a NetFetcher' do
        let(:fetcher) { NetFetcher.new(subject) }

        it 'should return the default version' do
          get_version_for_cache('1.2.6')
        end
      end

      context 'with a GitFetcher' do
        let(:fetcher) do
          a = GitFetcher.new(subject)
          allow(a).to receive(:target_revision).and_return('4b19a96d57bff9bbf4764d7323b92a0944009b9e')
          a
        end

        it 'should return the git sha' do
          get_version_for_cache('4b19a96d57bff9bbf4764d7323b92a0944009b9e')
        end
      end
    end

    describe '#shasum' do
      context 'when a filepath is given' do
        let(:path) { '/software.rb' }
        let(:file) { double(File) }

        subject do
          software = described_class.new(project, {}, path)
          software.name('software')
          software.version('1.0.0')
          software
        end

        before do
          allow(File).to receive(:exist?)
            .with(path)
            .and_return(true)
          allow(File).to receive(:open)
            .with(path)
            .and_return(file)
        end

        it 'returns the correct shasum' do
          expect(subject.shasum).to eq('348b605ee8e8325ad32a4837f0784aa2203b19a87a820dd4456dd5a798a62713')
        end
      end

      context 'when a filepath is not given' do
        subject do
          software = described_class.new(project, {})
          software.name('software')
          software.version('1.0.0')
          software
        end

        it 'returns the correct shasum' do
          expect(subject.shasum).to eq('333f0052cc38f15e7f6c4d5b3e2a5337a01888f621e162476ecbf5eb91ae8a30')
        end
      end
    end
  end
end
