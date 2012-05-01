#
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'ohai'
o = Ohai::System.new
o.require_plugin('os')
o.require_plugin('platform')
o.require_plugin('linux/cpu') if o.os == 'linux'
o.require_plugin('kernel')
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
require 'omnibus/clean_tasks'
require 'omnibus/build_version'

module Omnibus

  def self.root=(root)
    @root = root
  end

  def self.root
    @root
  end

  def self.gem_root=(root)
    @gem_root = root
  end

  def self.gem_root
    @gem_root
  end

  def self.setup(options = {})
    self.root = Dir.pwd
    self.gem_root = File.expand_path("../../", __FILE__)
    load_config
    yield self if block_given?
    # Load core software tasks
    software "#{gem_root}/config/software/*.rb" unless options[:no_core_software]
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
        Omnibus::Project.all_projects.each do |p|
          s = Omnibus::Software.load(f, p)
          # TODO: only load and register needed software for each project
          #
          # currently we are loading and registering every software
          # definition for every project and relying on the fact that
          # the depenendency tree for the project won't build the
          # unnecessary bits. What does happen, however, is that the
          # version manifest for a particular project will have the
          # versions for ALLTHETHINGS. Currently (04/05/12) this is
          # fine since chef-full is a subset of private-chef. This
          # should be fixed as soon as we have the extra time.
          Omnibus.component_added(s)
        end
      end
    end

    def self.projects(*path_specs)
      FileList[*path_specs].each do |f|
        p = Omnibus::Project.load(f)
        Omnibus::Project.all_projects << p
        p
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

