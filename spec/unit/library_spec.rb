require 'spec_helper'
require 'omnibus/library'
require 'omnibus/project'

describe Omnibus::Library do
  let(:project) { Omnibus::Project.load(project_path('chefdk')) }
  let(:library) { Omnibus::Library.new(project) }
  let(:erchef) { Omnibus::Software.load(software_path('erchef'), project) }
  let(:zlib) { Omnibus::Software.load(software_path('zlib'), project) }

  def gen_software(name, deps)
    software = Omnibus::Software.new('', "#{name}.rb", 'chef-server')
    software.name(name.to_s)
    deps.each do |dep|
      software.dependency(dep)
    end
    software
  end

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
dependency 'postgresql'
dependency 'chef'
EOH
      Omnibus::Project.new(raw_project, 'chef-server.rb')
    end

    let(:library) do
      library = Omnibus::Library.new(project)
      library.component_added(preparation)
      library.component_added(erlang)
      library.component_added(postgresql) # as a skitch trans dep
      library.component_added(skitch)
      library.component_added(erchef)
      library.component_added(ruby)
      library.component_added(chef)
      library
    end

    project_deps = [:preparation, :erchef, :postgresql, :chef]
    erchef_deps = [:erlang, :skitch]
    chef_deps = [:ruby]

    [project_deps, erchef_deps, chef_deps].flatten.each do |dep|
      let(dep) do
        software = Omnibus::Software.new('', "#{dep}.rb", 'chef-server')
        software.name(dep.to_s)
        software.dependency('postgresql') if dep == :skitch
        software
      end
    end

    it 'returns an array of software descriptions, with all top level deps first, assuming they are not themselves transitive deps' do
      library.build_order.map { |m| m.name.to_s }
      expect(library.build_order).to eql([preparation, erlang, postgresql, skitch, ruby, erchef, chef])
    end

    context 'with a complex dep tree' do
      # rubocop:disable all
      [
        ['preparation', []],
        ['erchef', ['erlang', 'skitch']],
        ['postgresql', []],
        ['erlang', []],
        ['skitch', ['postgresql']],
        ['chef', ['ruby', 'bundler', 'ohai']],
        ['ohai', ['ruby']],
        ['bundler', ['ruby']],
        ['ruby', []],
        ['chefdk', ['ruby', 'bundler']],
      ].each do |item|
        name = item[0]
        deps = item[1]
        let(name) do
          gen_software(name, deps)
        end
      end

      let(:project) do
        raw_project = <<-EOH
name "chef-dk"
install_path "/opt/chefdk"
build_version "1.0.0"
maintainer 'Chef Software, Inc'
homepage 'http://getchef.com'
dependency 'preparation'
dependency 'erchef'
dependency 'postgresql'
dependency 'ruby'
dependency 'chef'
dependency 'chefdk'
        EOH
        Omnibus::Project.new(raw_project, 'chefdk.rb')
      end

      let(:library) do
      # This is the LOAD ORDER
        library = Omnibus::Library.new(project)
        library.component_added(preparation) # via project
        library.component_added(erlang) # via erchef
        library.component_added(postgresql) # via skitch
        library.component_added(skitch) # via erchef
        library.component_added(erchef) # erchef
        library.component_added(ruby) # via project
        library.component_added(bundler) # via chef
        library.component_added(ohai) # via chef
        library.component_added(chef) # via project
        library.component_added(chefdk) # via project
        library
      end

      it 'returns an array of software descriptions, with all top level deps first, assuming they are not themselves transitive deps' do
        expect(library.build_order).to eql(
          [
            preparation, # first
            erlang, # via erchef project
            postgresql, # via skitch transitive
            skitch, # via erchef project
            ruby, # via bundler transitive
            bundler, # via chef
            ohai, # via chef
            erchef, # project dep
            chef, # project dep
            chefdk, # project dep
           ])
      end
    end

    context 'with real data' do
      before :each do
        allow_any_instance_of(Omnibus::Software).to receive(:platform).and_return('windows')
        Omnibus.stub(:project_root) do
          File.expand_path(
            File.join(
              File.dirname(__FILE__),
              '..',
              'data',
              'complicated'
            )
          )
        end
        Omnibus.process_dsl_files
      end

      after :each do
        Omnibus.class_eval { @projects = [] }
        Omnibus.class_eval { @software_dirs = nil }
      end

      let(:chefdk_windows) do
        Omnibus.projects.find { |p| p.name.to_s == 'chefdk-windows' }
      end

      it 'has the right build order for chefdk-windows on windows' do
        names = chefdk_windows.library.build_order.map { |m| m.name.to_s }
        expect(names).to eql([
          'preparation', # via project dep
          'ruby-windows', # via libyaml-windows trans dep
          'libyaml-windows', # via ruby-windows trans
          'ruby-windows-devkit', # via trans dep from chef-windows
          'bundler', # via trans dep from chef-windows
          'cacerts', # via chef-windows
          'chef-windows', # via transitive dep from chefdk
          'nokogiri', # via test-kitchen
          'test-kitchen', # via chefdk
          'appbundler', # via chefdk
          'berkshelf', # via chefdk
          'chef-vault', # via chefdk
          'chefdk', # via project dep
          'chef-client-msi', # via top level dep
        ])
      end
    end
  end

end
