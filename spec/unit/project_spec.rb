require 'spec_helper'
require 'ohai'

module Omnibus
  describe Project do
    subject do
      described_class.new.evaluate do
        name 'sample'
        friendly_name 'Sample Project'
        install_dir '/sample'
        maintainer 'Sample Devs'
        homepage 'http://example.com/'

        build_version '1.0'
        build_iteration 1

        extra_package_file '/path/to/sample_dir'
        extra_package_file '/path/to/file.conf'

        resources_path 'sample/project/resources'
      end
    end

    it_behaves_like 'a cleanroom setter', :name, %|name 'chef'|
    it_behaves_like 'a cleanroom setter', :friendly_name, %|friendly_name 'Chef'|
    it_behaves_like 'a cleanroom setter', :install_dir, %|install_dir '/opt/chef'|
    it_behaves_like 'a cleanroom setter', :maintainer, %|maintainer 'Chef Software, Inc'|
    it_behaves_like 'a cleanroom setter', :homepage, %|homepage 'https://getchef.com'|
    it_behaves_like 'a cleanroom setter', :description, %|description 'Installs the thing'|
    it_behaves_like 'a cleanroom setter', :replace, %|replace 'old-chef'|
    it_behaves_like 'a cleanroom setter', :conflict, %|conflict 'puppet'|
    it_behaves_like 'a cleanroom setter', :build_version, %|build_version '1.2.3'|
    it_behaves_like 'a cleanroom setter', :build_iteration, %|build_iteration 1|
    it_behaves_like 'a cleanroom setter', :package_user, %|package_user 'chef'|
    it_behaves_like 'a cleanroom setter', :package_group, %|package_group 'chef'|
    it_behaves_like 'a cleanroom setter', :override, %|override :chefdk, source: 'foo.com'|
    it_behaves_like 'a cleanroom setter', :resources_path, %|resources_path '/path'|
    it_behaves_like 'a cleanroom setter', :package_scripts_path, %|package_scripts_path '/path/scripts'|
    it_behaves_like 'a cleanroom setter', :dependency, %|dependency 'libxslt-dev'|
    it_behaves_like 'a cleanroom setter', :runtime_dependency, %|runtime_dependency 'libxslt'|
    it_behaves_like 'a cleanroom setter', :exclude, %|exclude 'hamlet'|
    it_behaves_like 'a cleanroom setter', :config_file, %|config_file '/path/to/config.rb'|
    it_behaves_like 'a cleanroom setter', :extra_package_file, %|extra_package_file '/path/to/asset'|

    describe 'basics' do
      it 'returns a name' do
        expect(subject.name).to eq('sample')
      end

      it 'returns an install_dir' do
        expect(subject.install_dir).to eq('/sample')
      end

      it 'returns a maintainer' do
        expect(subject.maintainer).to eq('Sample Devs')
      end

      it 'returns a homepage' do
        expect(subject.homepage).to eq('http://example.com/')
      end

      it 'returns a build version' do
        expect(subject.build_version).to eq('1.0')
      end

      it 'returns a build iteration' do
        expect(subject.build_iteration).to eq(1)
      end

      it 'returns an array of files and dirs' do
        expect(subject.extra_package_files).to eq(['/path/to/sample_dir', '/path/to/file.conf'])
      end

      it 'returns a friendly_name' do
        expect(subject.friendly_name).to eq('Sample Project')
      end

      it 'returns a resources_path' do
        expect(subject.resources_path).to include('sample/project/resources')
      end
    end

    describe '#dirty!' do
      it 'dirties the cache' do
        subject.instance_variable_set(:@dirty, nil)
        subject.dirty!
        expect(subject).to be_dirty
      end
    end

    describe '#dirty?' do
      it 'returns true by default' do
        subject.instance_variable_set(:@dirty, nil)
        expect(subject).to_not be_dirty
      end

      it 'returns true when the cache is dirty' do
        subject.instance_variable_set(:@dirty, true)
        expect(subject).to be_dirty
      end

      it 'returns false when the cache is not dirty' do
        subject.instance_variable_set(:@dirty, false)
        expect(subject).to_not be_dirty
      end
    end

    describe '#<=>' do
      let(:chefdk) { described_class.new.tap { |p| p.name('chefdk') } }
      let(:chef)   { described_class.new.tap { |p| p.name('chef') } }
      let(:ruby)   { described_class.new.tap { |p| p.name('ruby') } }

      it 'compares projects by name' do
        list = [chefdk, chef, ruby]
        expect(list.sort.map(&:name)).to eq(%w(chef chefdk ruby))
      end
    end

    describe '#build_iteration' do
      let(:fauxhai_options) { Hash.new }

      before { stub_ohai(fauxhai_options) }

      context 'when on RHEL' do
        let(:fauxhai_options) { { platform: 'redhat', version: '6.4' } }
        it 'returns a RHEL iteration' do
          expect(subject.build_iteration).to eq(1)
        end
      end

      context 'when on Debian' do
        let(:fauxhai_options) { { platform: 'debian', version: '7.2' } }
        it 'returns a Debian iteration' do
          expect(subject.build_iteration).to eq(1)
        end
      end

      context 'when on FreeBSD' do
        let(:fauxhai_options) { { platform: 'freebsd', version: '9.1' } }
        it 'returns a FreeBSD iteration' do
          expect(subject.build_iteration).to eq(1)
        end
      end

      context 'when on Windows' do
        before { stub_ohai(platform: 'windows', version: '2008R2') }
        before { stub_const('File::ALT_SEPARATOR', '\\') }
        it 'returns a Windows iteration' do
          expect(subject.build_iteration).to eq(1)
        end
      end

      context 'when on OS X' do
        let(:fauxhai_options) { { platform: 'mac_os_x', version: '10.8.2' } }
        it 'returns a generic iteration' do
          expect(subject.build_iteration).to eq(1)
        end
      end
    end

    describe '#overrides' do
      before { subject.overrides.clear }

      it 'sets all the things through #overrides' do
        subject.override(:thing, version: '6.6.6')
        expect(subject.override(:zlib)).to be_nil
      end

      it 'retrieves the things set through #overrides' do
        subject.override(:thing, version: '6.6.6')
        expect(subject.override(:thing)[:version]).to eq('6.6.6')
      end
    end

    describe '#shasum' do
      context 'when a filepath is given' do
        let(:path) { '/project.rb' }
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

        it 'returns the correct shasum' do
          expect(subject.shasum).to eq('2cb8bdd11c766caa11a37607e84ffb51af3ae3da16931988f12f7fc9de98d68e')
        end
      end

      context 'when a filepath is not given' do
        before { subject.send(:remove_instance_variable, :@filepath) }

        it 'returns the correct shasum' do
          expect(subject.shasum).to eq('3cc6bd98da4d643b79c71be2c93761a458b442e2931f7d421636f526d0c1e8bf')
        end
      end
    end
  end
end
