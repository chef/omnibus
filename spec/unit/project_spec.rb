require 'spec_helper'
require 'ohai'

module Omnibus
  describe Project do
    let(:project) { Project.load(project_path('sample')) }

    subject { project }

    shared_examples 'a cleanroom setter' do |id, value|
      it "for `#{id}'" do
        expect { subject.evaluate("#{id}(#{value.inspect})") }
          .to_not raise_error
      end
    end

    shared_examples 'a cleanroom getter' do |id|
      it "for `#{id}'" do
        expect { subject.evaluate("#{id}") }.to_not raise_error
      end
    end

    it_behaves_like 'a cleanroom setter', :name, 'chef'
    it_behaves_like 'a cleanroom setter', :friendly_name, 'Chef'
    it_behaves_like 'a cleanroom setter', :msi_parameters, { foo: 'bar' }
    it_behaves_like 'a cleanroom setter', :package_name, 'chef.package'
    it_behaves_like 'a cleanroom setter', :install_path, '/opt/chef'
    it_behaves_like 'a cleanroom setter', :maintainer, 'Chef Software, Inc'
    it_behaves_like 'a cleanroom setter', :homepage, 'https://getchef.com'
    it_behaves_like 'a cleanroom setter', :description, 'Installs the thing'
    it_behaves_like 'a cleanroom setter', :replaces, 'old-chef'
    it_behaves_like 'a cleanroom setter', :conflict, 'puppet'
    it_behaves_like 'a cleanroom setter', :build_version, '1.2.3'
    it_behaves_like 'a cleanroom setter', :build_iteration, 1
    it_behaves_like 'a cleanroom setter', :mac_pkg_identifier, 'com.getchef'
    it_behaves_like 'a cleanroom setter', :package_user, 'chef'
    it_behaves_like 'a cleanroom setter', :package_group, 'chef'
    it_behaves_like 'a cleanroom setter', :override, 'foo'
    it_behaves_like 'a cleanroom setter', :resources_path, '/path'
    it_behaves_like 'a cleanroom setter', :dependency, 'libxslt-dev'
    it_behaves_like 'a cleanroom setter', :runtime_dependency, 'libxslt'
    it_behaves_like 'a cleanroom setter', :exclude, 'hamlet'
    it_behaves_like 'a cleanroom setter', :config_file, '/path/to/config.rb'
    it_behaves_like 'a cleanroom setter', :extra_package_file, '/path/to/asset'

    it_behaves_like 'a cleanroom getter', :files_path

    describe 'basics' do
      it 'should return a name' do
        expect(project.name).to eq('sample')
      end

      it 'should return an install path' do
        expect(project.install_path).to eq('/sample')
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

      it 'should return friendly_name' do
        expect(project.resources_path).to eq('sample/project/resources')
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

      before do
        stub_ohai(Fauxhai.mock(fauxhai_options).data)
      end

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
  end
end
