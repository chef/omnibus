require 'spec_helper'

module Omnibus
  describe Packager::MacDmg, :functional, :mac_only do
    let(:name) { 'sample' }
    let(:version) { '12.4.0' }

    let(:project) do
      allow(IO).to receive(:read)
        .with('/project.rb')
        .and_return <<-EOH.gsub(/^ {10}/, '')
          name               '#{name}'
          maintainer         'Chef'
          homepage           'https://getchef.com'
          build_version      '#{version}'
          install_dir        '#{tmp_path}/opt/#{name}'
          mac_pkg_identifier 'test.pkg.#{name}'
        EOH

      Project.load('/project.rb')
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
      Config.project_root "#{fixtures_path}/sample"

      # Create the target directory
      FileUtils.mkdir_p(project.install_dir)
    end

    it 'builds a pkg and a dmg' do
      # Create the pkg resource
      mac_packager.run!

      # There is a tiny bit of hard-coding here, but I don't see a better
      # solution for generating the package name
      pkg = "#{Config.package_dir}/#{name}-#{version}-1.pkg"
      dmg = "#{Config.package_dir}/#{name}-#{version}-1.dmg"

      expect(pkg).to be_a_file
      expect(dmg).to be_a_file
    end
  end
end
