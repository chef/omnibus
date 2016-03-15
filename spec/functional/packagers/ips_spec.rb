require "spec_helper"
require "omnibus/config"
require "omnibus/packager"
require 'omnibus/packagers/base'
require "omnibus/packagers/ips"

context "ips packager" do
  let(:project_root) { File.join(tmp_path, 'project/root') }
  let(:package_dir)  { File.join(tmp_path, 'package/dir') }
#  let(:install_dir)  { File.join(tmp_path, 'install_dir')}
  let(:install_dir)  { '/opt/projectchef' }

  let(:project) do
    # p = instance_double(Omnibus::Project)
    # allow(p).to receive(:name).and_return("project")

    Omnibus::Project.new.tap do |project|
      project.name('projectchef')
      project.homepage('https://example.com')
      project.install_dir(install_dir)
      project.build_version('1.2.3')
      project.build_iteration('2')
      project.maintainer('Chef Software')
    end
  end

  let(:packager) do
    Omnibus::Packager::IPS.new(project)
  end

  before do
    Omnibus::Config.project_root(project_root)
    Omnibus::Config.package_dir(package_dir)
    FileUtils.mkdir_p(install_dir)
    FileUtils.mkdir_p(package_dir)
  end

  context "with a basic project" do
    it "should build a package" do
      packager.run!
      binding.pry
      expect(File.exist?(File.join(package_dir, packager.package_name)))
    end
  end
end
