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

module Omnibus

  #--
  # Extra indirection so we don't need the Rake::DSL in the Omnibus module
  module Loader
    extend Rake::DSL

    def self.software(*path_specs)
      FileList[*path_specs].each do |f|
        Omnibus::Software.new(IO.read(f))
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

