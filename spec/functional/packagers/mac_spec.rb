require 'spec_helper'

module Omnibus
  describe Packager::MacDmg, :functional, :mac_only do
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
      pkg = "#{project.package_dir}/#{name}-#{version}-1.pkg"
      dmg = "#{project.package_dir}/#{name}-#{version}-1.dmg"

      expect(File.exist?(pkg)).to be_truthy
      expect(File.exist?(dmg)).to be_truthy
    end
  end
end
