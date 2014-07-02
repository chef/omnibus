require 'spec_helper'
require 'ohai'

module Omnibus
  describe Project do
    let(:project) { Project.load(project_path('sample')) }

    subject { project }

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

    describe '#platform_version_for_package' do
      before { described_class.send(:public, :platform_version_for_package) }

      shared_examples 'a version manipulator' do |platform, version, family, expected|
        context "on #{platform}-#{version} (#{family})" do
          before do
            allow(Ohai).to receive(:ohai).and_return(
              'platform'         => platform,
              'platform_version' => version,
              'platform_family'  => family,
            )
          end

          it 'returns the correct value' do
            expect(subject.platform_version_for_package).to eq(expected)
          end
        end
      end

      it_behaves_like 'a version manipulator', 'arch', '2009.02', 'arch', '2009.02'
      it_behaves_like 'a version manipulator', 'arch', '2014.06.01', 'arch', '2014.06'
      it_behaves_like 'a version manipulator', 'debian', '7.1', 'debian', '7'
      it_behaves_like 'a version manipulator', 'debian', '6.9', 'debian', '6'
      it_behaves_like 'a version manipulator', 'ubuntu', '10.04', 'debian', '10.04'
      it_behaves_like 'a version manipulator', 'ubuntu', '10.04.04', 'debian', '10.04'
      it_behaves_like 'a version manipulator', 'fedora', '11.5', 'fedora', '11'
      it_behaves_like 'a version manipulator', 'freebsd', '10.0', 'fedora', '10'
      it_behaves_like 'a version manipulator', 'rhel', '6.5', 'rhel', '6'
      it_behaves_like 'a version manipulator', 'centos', '5.9.6', 'rhel', '5'
      it_behaves_like 'a version manipulator', 'aix', '7.1', 'aix', '7.1'
      it_behaves_like 'a version manipulator', 'gentoo', '2004.3', 'aix', '2004.3'
      it_behaves_like 'a version manipulator', 'mac_os_x', '10.9.1', 'mac_os_x', '10.9'
      it_behaves_like 'a version manipulator', 'openbsd', '5.4.4', 'openbsd', '5.4'
      it_behaves_like 'a version manipulator', 'slackware', '12.0.1', 'slackware', '12.0'
      it_behaves_like 'a version manipulator', 'solaris', '5.9', 'solaris2', '5.9'
      it_behaves_like 'a version manipulator', 'suse', '5.9', 'suse', '5.9'
      it_behaves_like 'a version manipulator', 'omnios', 'r151010', 'omnios', 'r151010'
      it_behaves_like 'a version manipulator', 'smartos', '20120809T221258Z', 'smartos', '20120809T221258Z'
      it_behaves_like 'a version manipulator', 'windows', '6.1.7600', 'windows', '7'
      it_behaves_like 'a version manipulator', 'windows', '6.1.7601', 'windows', '2008r2'
      it_behaves_like 'a version manipulator', 'windows', '6.2.9200', 'windows', '8'
      it_behaves_like 'a version manipulator', 'windows', '6.3.9200', 'windows', '8.1'

      context 'given an unknown platform' do
        before do
          allow(Ohai).to receive(:ohai).and_return(
            'platform'         => 'bacon',
            'platform_version' => '1.crispy',
            'platform_family'  => 'meats',
          )
        end

        it 'raises an exception' do
          expect { subject.platform_version_for_package }
            .to raise_error(UnknownPlatformFamily)
        end
      end

      context 'given an unknown windows platform version' do
        before do
          allow(Ohai).to receive(:ohai).and_return(
            'platform'         => 'windows',
            'platform_version' => '1.2.3',
            'platform_family'  => 'windows',
          )
        end

        it 'raises an exception' do
          expect { subject.platform_version_for_package }
            .to raise_error(UnknownPlatformVersion)
        end
      end
    end
  end
end
