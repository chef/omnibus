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
  describe Packager::WindowsMsi, :functional, :windows_only do
    let(:name) { 'sample' }
    let(:version) { '12.4.0' }

    let(:project) do
      Project.new(<<-EOH, __FILE__)
        name               '#{name}'
        maintainer         'Chef'
        homepage           'https://getchef.com'
        build_version      '#{version}'
        install_path       '#{tmp_path}\\opt\\#{name}'
      EOH
    end

    let(:windows_packager) { Packager::WindowsMsi.new(project) }

    before do
      # Tell things to install into the cache directory
      root = "#{tmp_path}/var/omnibus"
      Config.cache_dir "#{root}/cache"
      Config.install_path_cache_dir "#{root}/cache/install_path"
      Config.source_dir "#{root}/src"
      Config.build_dir "#{root}/build"
      Config.package_dir "#{root}/pkg"
      Config.package_tmp "#{root}/pkg-tmp"

      # Point at our sample project fixture
      Config.project_root "#{fixtures_path}/sample"

      # Create the target directory
      FileUtils.mkdir_p(project.install_path)

      # Create a file to be included in the MSI
      FileUtils.touch(File.join(project.install_path, 'golden_file'))
    end

    it 'builds a pkg and a dmg' do
      # Create the pkg resource
      windows_packager.run!

      # There is a tiny bit of hard-coding here, but I don't see a better
      # solution for generating the package name
      expect(File.exist?("#{project.package_dir}/#{name}-#{version}-1.windows.msi")).to be_truthy
    end
  end
end
