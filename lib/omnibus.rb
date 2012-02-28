require 'rake/clean'
CLEAN.include('/tmp/omnibus/**/*')
CLOBBER.include('/opt/opscode/**/*')

require 'ohai'
o = Ohai::System.new
o.require_plugin('os')
o.require_plugin('platform')
OHAI = o

require 'omnibus/library'
require 'omnibus/reports'
require 'omnibus/config'
require 'omnibus/software'
require 'omnibus/project'
require 'omnibus/fetchers'
require 'omnibus/s3_cacher'
require 'omnibus/s3_tasks'
require 'omnibus/health_check'

module Omnibus

  def self.root=(root)
    @root = root
  end

  def self.root
    @root
  end

  def self.setup
    self.root = Dir.pwd
    load_config
  end

  def self.config_path
    File.expand_path("omnibus.rb", root)
  end

  def self.load_config
    if File.exist?(config_path)
      TOPLEVEL_BINDING.eval(IO.read(config_path))
    else
      puts("No config file found in #{config_path}, exiting.")
      exit 1
    end
  end

  #--
  # Extra indirection so we don't need the Rake::DSL in the Omnibus module
  module Loader
    extend Rake::DSL

    def self.software(*path_specs)
      FileList[*path_specs].each do |f|
        s = Omnibus::Software.load(f)
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

