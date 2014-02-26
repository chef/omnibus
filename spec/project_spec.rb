#
# Copyright:: Copyright (c) 2014 Noah Kantrowitz
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'

require 'omnibus/project'

describe Omnibus::Project do
  let(:project) do
    Omnibus::Project.load(project_path('sample'))
  end

  subject { project }

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
  end

  describe '#iteration' do
    let(:fauxhai_options) { Hash.new }
    around(:each) do |example|
      data = OHAI.data
      begin
        OHAI.data = Mash.new(Fauxhai.mock(fauxhai_options).data)
        example.run
      ensure
        OHAI.data = data
      end
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
      it 'should return a Windows iteration' do
        expect(project.iteration).to eq('1.windows')
      end
    end

    context 'when on OS X' do
      let(:fauxhai_options) { { platform: 'mac_os_x', version: '10.8.2' } }
      it 'should return a generic iteration' do
        expect(project.iteration).to eq('1.mac_os_x.10.8.2')
      end
    end
  end

  describe '#overrides' do
    let(:project) { Omnibus::Project.load(project_path('chefdk')) }

    it 'should set an override for the zlib version' do
      expect(project.overrides[:zlib][:version]).to eq('1.2.8')
    end

    it 'should access the zlib version through the #override method as well' do
      expect(project.override(:zlib)[:version]).to eq('1.2.8')
    end

    it 'should set all the things through #overrides' do
      project.overrides(thing: { version: '6.6.6' })
      expect(project.override(:zlib)).to be_nil
    end

    it 'should retrieve the things set through #overrides' do
      project.overrides(thing: { version: '6.6.6' })
      expect(project.override(:thing)[:version]).to eq('6.6.6')
    end

    it 'should not set other things through setting a single #override' do
      project.override(:thing, version: '6.6.6')
      expect(project.override(:zlib)[:version]).to eq('1.2.8')
    end

    it 'should retrieve the things set through #overrides' do
      project.override(:thing, version: '6.6.6')
      expect(project.override(:thing)[:version]).to eq('6.6.6')
    end
  end
end
