require 'spec_helper'

module Omnibus
  describe Packager::Makeself do
    let(:project_name) { 'myproject' }

    let(:omnibus_root) { '/omnibus/project/root' }

    let(:package_scripts_path) { "#{omnibus_root}/scripts" }

    let(:project) do
      double(Project,
        name: project_name,
        package_name: project_name,
        build_version: '23.4.2',
        build_iteration: 4,
        install_dir: '/opt/myproject',
        package_scripts_path: package_scripts_path
      )
    end

    let(:packager) { described_class.new(project) }

    describe '#package_name' do
      it 'names the product package PROJECT_NAME.sh' do
        expect(packager.package_name).to eq('myproject-23.4.2_4.x86_64.sh')
      end
    end

    describe '#makeself_cmd' do
      it 'generates the correct makeself command' do
        expect(packager.makeself_cmd).to eq("#{Omnibus.source_root}/bin/makeself.sh --gzip /opt/myproject myproject-23.4.2_4.x86_64.sh 'The full stack of myproject'")
      end
    end
  end
end
