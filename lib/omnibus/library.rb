module Omnibus
  #
  # Used to generate the manifest of all software components with versions
  class Library

    def initialize
      @projects = []
      @components = []
    end

    def component_added(component)
      @components << component
    end

    def version_map(project)
      @components.select {|c| c.project == project}.inject({}) {|map, component|
        map[component.name] = component.version; map
      }
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

end

