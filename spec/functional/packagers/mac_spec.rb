#
# Copyright:: Copyright (c) 2014 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'

module Omnibus
  describe Packager::MacDmg, :functional do
    let(:name) { 'sample' }
    let(:version) { '12.4.0' }

    let(:project) do
      Project.new(<<-EOH, __FILE__)
        name               '#{name}'
        maintainer         'Chef'
        homepage           'https://getchef.com'
        build_version      '#{version}'
        install_path       '#{tmp_path}/opt/#{name}'
        mac_pkg_identifier 'test.pkg.#{name}'
      EOH
    end

    let(:mac_packager) { Packager::MacPkg.new(project) }

    before do
      # Reset stale configuration
      Omnibus.config.reset!

      # Tell things to install into the cache directory
      root = "#{tmp_path}/var/omnibus"
      Omnibus.config.cache_dir "#{root}/cache"
      Omnibus.config.install_path_cache_dir "#{root}/cache/install_path"
      Omnibus.config.source_dir "#{root}/src"
      Omnibus.config.build_dir "#{root}/build"
      Omnibus.config.package_dir "#{root}/pkg"
      Omnibus.config.package_tmp "#{root}/pkg-tmp"

      # Enable DMG create
      Omnibus.config.build_dmg true

      # Point at our sample project fixture
      Omnibus.config.project_root "#{fixtures_path}/sample"

      # Create the target directory
      FileUtils.mkdir_p(project.install_path)
    end

    it 'builds a pkg and a dmg' do
      # Create the pkg resource
      mac_packager.run!

      # There is a tiny bit of hard-coding here, but I don't see a better
      # solution for generating the package name
      pkg = "#{project.package_dir}/#{name}-#{version}-1.mac_os_x.10.9.2.pkg"
      dmg = "#{project.package_dir}/#{name}-#{version}-1.mac_os_x.10.9.2.dmg"

      expect(File.exist?(pkg)).to be_true
      expect(File.exist?(dmg)).to be_true
    end
  end
end
