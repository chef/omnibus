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

    it 'builds a msi' do
      # Create the msi resource
      subject.run!

      # There is a tiny bit of hard-coding here, but I don't see a better
      # solution for generating the package name
      expect("#{Config.package_dir}/sample-12.4.0-1.windows.msi").to be_a_file
    end
  end
end
