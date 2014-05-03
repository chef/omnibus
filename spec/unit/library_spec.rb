require 'spec_helper'
require 'omnibus/library'
require 'omnibus/project'

describe Omnibus::Library do

  SoftwareGraph = Struct.new(:name, :deps)

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

    def software_defn_from_graph_node(graph)
      software = Omnibus::Software.new('', "#{graph.name}.rb", 'chef-server')
      software.name(graph.name.to_s)
      graph.deps.each do |dep|
        software.dependency(dep)
      end
      library.component_added(software)
      software
    end

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
      Omnibus::Library.new(project)
    end

    let(:basic_project) do
      Omnibus::Project.load(project_path('chefdk')).tap do |p|
        p.dependencies.clear
      end
    end

    context "when a project depends on a non-existent component" do
      let(:project) do
        project = basic_project.dup
        project.dependency(:chefdk)
        project
      end

      it "raises an error" do
        expect { library.build_order }.to raise_error(Omnibus::MissingProjectDependency)
      end

    end

    context "when a software definition dependends on a non-existent component" do
      let(:project) do
        project = basic_project.dup
        project.dependency(:chefdk)
        project
      end

      let!(:chefdk) do
        graph_node = SoftwareGraph.new(:chefdk, [:nopenopenope])
        software_defn_from_graph_node(graph_node)
      end

      it "raises an error" do
        expect { library.build_order }.to raise_error(Omnibus::MissingSoftwareDependency)
      end

    end

    context "when a software defintion depends on itself" do
      let(:project) do
        project = basic_project.dup
        project.dependency(:chefdk)
        project
      end

      let!(:chefdk) do
        graph_node = SoftwareGraph.new(:chefdk, [:chefdk])
        software_defn_from_graph_node(graph_node)
      end

      it "sorts the dependency without error or infinite loop" do
        expect(library.build_order).to eql([chefdk])
      end

    end

    context "when a software definition has a circular dep" do

      let(:project) do
        project = basic_project.dup
        project.dependency(:chefdk)
        project
      end

      let!(:chefdk) do
        graph_node = SoftwareGraph.new(:chefdk, [:bundler])
        software_defn_from_graph_node(graph_node)
      end

      let!(:bundler) do
        graph_node = SoftwareGraph.new(:bundler, [:chefdk])
        software_defn_from_graph_node(graph_node)
      end

      it "sorts the dependency without error or infinite loop" do
        expect(library.build_order).to eql([bundler, chefdk])
      end

    end

    context "when software definitions have duplicate transitive dependencies" do

      project_deps = SoftwareGraph.new(:project, [:preparation, :erchef, :postgresql, :ruby, :chef])

      let(:project) do
        project = basic_project.dup
        project_deps.deps.each do |dep|
          project.dependency(dep)
        end
        project
      end

      graph_nodes = [
        SoftwareGraph.new(:preparation, []),
        SoftwareGraph.new(:erchef, [:erlang, :skitch]),
        SoftwareGraph.new(:postgresql, []),
        SoftwareGraph.new(:erlang, []),
        SoftwareGraph.new(:skitch, [:postgresql]),
        SoftwareGraph.new(:chef, [:ruby, :bundler]),
        SoftwareGraph.new(:ohai, [:ruby]),
        SoftwareGraph.new(:bundler, [:ruby]),
        SoftwareGraph.new(:ruby, []),
        SoftwareGraph.new(:chefdk, [:ruby, :bundler]),
      ]

      graph_nodes.each do |graph|
        let!(graph.name) do
          software_defn_from_graph_node(graph)
        end
      end

      it 'returns an array of software descriptions, with all top level deps first, assuming they are not themselves transitive deps' do
        names = library.build_order.map { |m| m.name.to_s }

        expect(names).to eq(%w[preparation erlang postgresql skitch erchef ruby bundler chef])

        expect(library.build_order).to eql([preparation, erlang, postgresql, skitch, erchef, ruby, bundler, chef])
      end
    end
  end

end
