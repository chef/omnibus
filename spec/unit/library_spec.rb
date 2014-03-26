require 'spec_helper'
require 'omnibus/library'
require 'omnibus/project'

describe Omnibus::Library do
  let(:project) { Omnibus::Project.load(project_path('chefdk')) }
  let(:library) { Omnibus::Library.new(project) }
  let(:erchef) { Omnibus::Software.load(software_path('erchef'), project) }
  let(:zlib) { Omnibus::Software.load(software_path('zlib'), project) }

  describe '#component_added' do
    it 'adds the software to the component list' do
      library.component_added(erchef)
      expect(library.components).to eql([erchef])
    end

    it 'does not add a component more than once' do
      library.component_added(erchef)
      library.component_added(erchef)
      expect(library.components).to eql([erchef])
    end
  end

  describe '#build_order' do
    let(:project) do
      raw_project = <<-EOH
name "chef-server"
install_path "/opt/chef-server"
build_version "1.0.0"
maintainer 'Chef Software, Inc'
homepage 'http://getchef.com'
dependency 'preparation'
dependency 'erchef'
dependency 'chef'
EOH
      Omnibus::Project.new(raw_project, 'chef-server.rb')
    end

    let(:library) do
      library = Omnibus::Library.new(project)
      library.component_added(preparation)
      library.component_added(erlang)
      library.component_added(skitch)
      library.component_added(erchef)
      library.component_added(ruby)
      library.component_added(chef)
      library
    end

    project_deps = [:preparation, :erchef, :chef]
    erchef_deps = [:erlang, :skitch]
    chef_deps = [:ruby]

    [project_deps, erchef_deps, chef_deps].flatten.each do |dep|
      let(dep) do
        software = Omnibus::Software.new('', "#{dep}.rb", 'chef-server')
        software.name(dep.to_s)
        software
      end
    end

    it 'returns an array of software descriptions, with all non top level deps first' do
      expect(library.build_order).to eql([preparation, erlang, skitch, ruby, erchef, chef])
    end
  end

end
