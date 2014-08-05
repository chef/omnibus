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
  describe Packager::MSI, :functional, :windows_only do
    let(:project) do
      Project.new('/project.rb').evaluate do
        name          'sample'
        maintainer    'Chef'
        homepage      'https://getchef.com'
        build_version '12.4.0'
        install_dir   File.join(tmp_path, opt, 'sample')
      end
    end

    subject { described_class.new(project) }

    before do
      # Tell things to install into the cache directory
      root = "#{tmp_path}/var/omnibus"

      Config.cache_dir "#{root}/cache"
      Config.git_cache_dir "#{root}/cache/git_cache"
      Config.source_dir "#{root}/src"
      Config.build_dir "#{root}/build"
      Config.package_dir "#{root}/pkg"

      # Packages are built into a tmpdir, but we control that here
      allow(Dir).to receive(:mktmpdir).and_return("#{root}/tmp")

      # Point at our sample project fixture
      Config.project_root fixture_path('sample')

      # Create the target directory
      FileUtils.mkdir_p(project.install_dir)

      # Create a file to be included in the MSI
      FileUtils.touch(File.join(project.install_dir, 'golden_file'))
    end

    it 'builds a pkg and a dmg' do
      # Create the pkg resource
      subject.run!

      # There is a tiny bit of hard-coding here, but I don't see a better
      # solution for generating the package name
      expect("#{Config.package_dir}/sample-12.4.0-1.windows.msi").to be_a_file
    end
  end
end
