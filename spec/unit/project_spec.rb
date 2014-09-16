require 'spec_helper'
require 'ohai'

module Omnibus
  describe Project do
    let(:project) { Project.load(project_path('sample')) }

    subject { project }

    it_behaves_like 'a cleanroom setter', :name, %|name 'chef'|
    it_behaves_like 'a cleanroom setter', :friendly_name, %|friendly_name 'Chef'|
    it_behaves_like 'a cleanroom setter', :msi_parameters, %|msi_parameters {}|
    it_behaves_like 'a cleanroom setter', :package_name, %|package_name 'chef.package'|
    it_behaves_like 'a cleanroom setter', :install_dir, %|install_dir '/opt/chef'|
    it_behaves_like 'a cleanroom setter', :install_path, %|install_path '/opt/chef'|
    it_behaves_like 'a cleanroom setter', :maintainer, %|maintainer 'Chef Software, Inc'|
    it_behaves_like 'a cleanroom setter', :homepage, %|homepage 'https://getchef.com'|
    it_behaves_like 'a cleanroom setter', :description, %|description 'Installs the thing'|
    it_behaves_like 'a cleanroom setter', :replaces, %|replaces 'old-chef'|
    it_behaves_like 'a cleanroom setter', :conflict, %|conflict 'puppet'|
    it_behaves_like 'a cleanroom setter', :build_version, %|build_version '1.2.3'|
    it_behaves_like 'a cleanroom setter', :build_iteration, %|build_iteration 1|
    it_behaves_like 'a cleanroom setter', :mac_pkg_identifier, %|mac_pkg_identifier 'com.getchef'|
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
    it_behaves_like 'a cleanroom setter', :dependencies, %|dependencies 'a', 'b', 'c'|

    it_behaves_like 'a cleanroom getter', :files_path

    describe 'basics' do
      it 'should return a name' do
        expect(project.name).to eq('sample')
      end

      it 'should return an install_dir' do
        expect(project.install_dir).to eq('/sample')
      end

      it 'should return a maintainer' do
        expect(project.maintainer).to eq('Sample Devs')
      end

      it 'should return a homepage' do
        expect(project.homepage).to eq('http://example.com/')
      end

      it 'should return a build version' do
        expect(project.build_version).to eq('1.0')
      end

      it 'should return a build iteration' do
        expect(project.build_iteration).to eq('1')
      end

      it 'should return an array of files and dirs' do
        expect(project.extra_package_files).to eq(['/path/to/sample_dir', '/path/to/file.conf'])
      end

      it 'should return friendly_name' do
        expect(project.friendly_name).to eq('Sample Project')
      end

      it 'should return resources_path' do
        expect(project.resources_path).to include('sample/project/resources')
      end
    end

    describe '#package_user' do
      it 'returns root by default' do
        subject.instance_variable_set(:@package_user, nil)
        expect(subject.package_user).to eq('root')
      end
    end

    describe '#package_group' do
      it 'returns root by default' do
        subject.instance_variable_set(:@package_group, nil)
        expect(subject.package_group).to eq('root')
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
      it 'compares projects by name' do
        list = [
          project,
          Project.load(project_path('chefdk')),
        ]
        expect(list.sort.map(&:name)).to eq(%w(chefdk sample))
      end
    end

    describe '#iteration' do
      let(:fauxhai_options) { Hash.new }

      before { stub_ohai(fauxhai_options) }

      context 'when on RHEL' do
        let(:fauxhai_options) { { platform: 'redhat', version: '6.4' } }
        it 'should return a RHEL iteration' do
          expect(project.iteration).to eq('1.el6')
        end
      end

      context 'when on Debian' do
        let(:fauxhai_options) { { platform: 'debian', version: '7.2' } }
        it 'should return a Debian iteration' do
          expect(project.iteration).to eq('1')
        end
      end

      context 'when on FreeBSD' do
        let(:fauxhai_options) { { platform: 'freebsd', version: '9.1' } }
        it 'should return a FreeBSD iteration' do
          expect(project.iteration).to eq('1.freebsd.9.amd64')
        end
      end

      context 'when on Windows' do
        let(:fauxhai_options) { { platform: 'windows', version: '2008R2' } }
        before { stub_const('File::ALT_SEPARATOR', '\\') }
        it 'should return a Windows iteration' do
          expect(project.iteration).to eq('1.windows')
        end
      end

      context 'when on OS X' do
        let(:fauxhai_options) { { platform: 'mac_os_x', version: '10.8.2' } }
        it 'should return a generic iteration' do
          expect(project.iteration).to eq('1')
        end
      end
    end

    describe '#overrides' do
      let(:project) { Project.load(project_path('chefdk')) }

      before { project.overrides.clear }


      it 'should set all the things through #overrides' do
        project.override(:thing, version: '6.6.6')
        expect(project.override(:zlib)).to be_nil
      end

      it 'retrieves the things set through #overrides' do
        project.override(:thing, version: '6.6.6')
        expect(project.override(:thing)[:version]).to eq('6.6.6')
      end
    end

    describe '#shasum' do
      context 'when a filepath is given' do
        let(:path) { '/project.rb' }
        let(:file) { double(File) }

        subject do
          project = described_class.new(path)
          project.name('project')
          project.install_dir('/opt/project')
          project.build_version('1.0.0')
          project
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
          expect(subject.shasum).to eq('8270d9078b577d3bedc2353ba3dc33fda1f8e69db3b7c0b449183a3e0e560d09')
        end
      end

      context 'when a filepath is not given' do
        subject do
          project = described_class.new
          project.name('project')
          project.install_dir('/opt/project')
          project.build_version('1.0.0')
          project
        end

        it 'returns the correct shasum' do
          expect(subject.shasum).to eq('545571a6041129f1224741a700c776b960cb093d4260ff6ca78b6a34bc130b45')
        end
      end
    end

  end
end
