require 'rake/clean'
CLEAN.include('/tmp/omnibus/**/*')
CLOBBER.include('/opt/opscode/**/*')

require 'ohai'
o = Ohai::System.new
o.require_plugin('os')
o.require_plugin('platform')
OHAI = o

require 'omnibus/software'
require 'omnibus/project'
require 'omnibus/fetchers'
require 'omnibus/s3_cacher'

module Omnibus

  # Used to generate the manifest of all software components with versions
  class Library

    def initialize
      @projects = []
      @components = []
    end

    def component_added(component)
      @components << component
    end

    def version_map
      @components.inject({}) {|map, component| map[component.name] = component.version; map}
    end

    def select(*args, &block)
      @components.select(*args, &block)
    end


  end

  def self.library
    @library ||= Library.new
  end

  def self.component_added(*args)
    library.component_added(*args)
  end

  module Reports
    extend self

    def pretty_version_map
      out = ""
      version_map = Omnibus.library.version_map
      width = version_map.keys.max {|a,b| a.size <=> b.size }.size + 3
      version_map.keys.sort.each do |name|
        version = version_map[name]
        out << "#{name}:".ljust(width) << version.to_s << "\n"
      end
      out
    end

  end

  #--
  # Extra indirection so we don't need the Rake::DSL in the Omnibus module
  module Loader
    extend Rake::DSL

    def self.software(*path_specs)
      FileList[*path_specs].each do |f|
        s = Omnibus::Software.new(IO.read(f))
        Omnibus.component_added(s)
        s
      end
    end

    def self.projects(*path_specs)
      FileList[*path_specs].each do |f|
        Omnibus::Project.new(IO.read(f))
      end
    end
  end

  def self.software(*path_specs)
    Loader.software(*path_specs)
  end

  def self.projects(*path_specs)
    Loader.projects(*path_specs)
  end
end

