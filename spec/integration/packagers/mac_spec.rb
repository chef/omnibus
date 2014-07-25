require 'spec_helper'

module Omnibus
  describe Packager::MacDmg, :functional, :mac_only do
    let(:project) do
      Project.new('/project.rb').evaluate do
        name               'sample'
        maintainer         'Chef'
        homepage           'https://getchef.com'
        build_version      '12.4.0'
        install_dir        File.join(tmp_path, 'opt', 'sample')
        mac_pkg_identifier 'test.pkg.sa,ple'
      end
    end

    let(:mac_packager) { Packager::MacPkg.new(project) }

    before do
      # Tell things to install into the cache directory
      root = "#{tmp_path}/var/omnibus"
      Config.cache_dir "#{root}/cache"
      Config.git_cache_dir "#{root}/cache/git_cache"
      Config.source_dir "#{root}/src"
      Config.build_dir "#{root}/build"
      Config.package_dir "#{root}/pkg"
      Config.package_tmp "#{root}/pkg-tmp"

      # Enable DMG create
      Config.build_dmg true

      # Point at our sample project fixture
      Config.project_root fixture_path('sample')

      # Create the target directory
      FileUtils.mkdir_p(project.install_dir)
    end

    it 'builds a pkg and a dmg' do
      # Create the pkg resource
      mac_packager.run!

      # There is a tiny bit of hard-coding here, but I don't see a better
      # solution for generating the package name
      pkg = "#{Config.package_dir}/sample-12.4.0-1.pkg"
      dmg = "#{Config.package_dir}/sample-12.4.0-1.dmg"

      expect(pkg).to be_a_file
      expect(dmg).to be_a_file
    end
  end
end
