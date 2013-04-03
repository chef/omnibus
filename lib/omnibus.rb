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
require 'omnibus/health_check'
require 'omnibus/build_version'
require 'omnibus/overrides'

require 'pathname'

module Omnibus

  DEFAULT_CONFIG_FILENAME = 'omnibus.rb'.freeze

  # Configure Omnibus.
  #
  # After this has been called, the {Omnibus::Config} object is
  # available as `Omnibus.config`.
  #
  # @yieldparam config [Omnibus::Config] a new configuration object
  # @yieldreturn [void]
  #
  # @example Simple Configuration using Default Values
  #   Omnibus.configure
  # @example Configuring with a Block
  #   Omnibus.configure do |config|
  #     config.project_dir  = 'omnibus/files/projects'
  #     config.software_dir = 'omnibus/files/software'
  #   end
  # @return [void]
  def self.configure
    configuration = Omnibus::Config.new

    yield configuration if block_given?

    configuration.validate
    @configuration = configuration

    process_dsl_files(configuration)
    generate_extra_rake_tasks(configuration)
  end

  # Provide access to a completely set-up {Omnibus::Config} object.
  #
  # @raise [Omnibus::NoConfiguration] if Omnibus has not been configured yet.
  #
  # @see Omnibus#configure
  def self.config
    @configuration ||= raise NoConfiguration
  end

  # All the {Omnibus::Project} objects that have been created.
  #
  # @return [Array<Omnibus::Project>]
  def self.projects
    @projects ||= []
  end

  # The absolute path to the Omnibus project/repository directory.
  #
  # @return [Pathname]
  def self.project_root
    @project_root ||= Pathname.pwd
  end

  # The source root is the path to the root directory of the `omnibus` gem.
  #
  # @return [Pathname]
  def self.source_root
    @source_root ||= Pathname.new(File.expand_path("../..", __FILE__))
  end

  # The source root is the path to the root directory of the `omnibus-software`
  # gem.
  #
  # @return [Pathname]
  def self.omnibus_software_root
    @omnibus_software_root ||= begin
      if spec = Gem::Specification.find_all_by_name('omnibus-software').first
        Pathname.new(spec.gem_dir)
      else
        nil
      end
    end
  end

  # Backward compat alias
  #
  # @todo print a deprecation message
  class << self
    alias :root :project_root
  end

  private

  # Generates {Omnibus::Project}s for each project DSL file in
  # `project_specs`.  All projects are then accessible at
  # {Omnibus#projects}
  #
  # @param project_files [Array<String>] paths to all the project DSL
  #   files to expand
  # @return [void]
  #
  # @see Omnibus::Project
  def self.expand_projects(project_files)
    project_files.each do |spec|
      Omnibus.projects << Omnibus::Project.load(spec)
    end
  end

  # Generate {Omnibus::Software} objects for all software DSL files in
  # `software_specs`.
  #
  # @param overrides [Hash] a hash of version override information.
  # @param software_files [Array<String>]
  # @return [void]
  #
  # @see Omnibus::Overrides#overrides
  def self.expand_software(overrides, software_files)
    unless overrides.is_a? Hash
      raise ArgumentError, "Overrides argument must be a hash!  You passed #{overrides.inspect}."
    end

    # TODO: Why are we doing a full Cartesian product of (projects x
    # software) without regard for the actual dependencies of the
    # projects?
    software_files.each do |f|
      Omnibus.projects.each do |p|
        s = Omnibus::Software.load(f, p, overrides)
        Omnibus.component_added(s) if p.dependency?(s)
      end
    end
  end

  # Processes all configured {Omnibus::Project} and
  # {Omnibus::Software} DSL files.
  #
  # @param config [Omnibus::Config]
  # @return [void]
  def self.process_dsl_files(config)

    # Do projects first
    project_files = ruby_files(config.project_dir)
    expand_projects(project_files)

    # Then do software
    software_files = prefer_local_software(omnibus_software_files,
                                           ruby_files(config.software_dir))

    overrides = config.override_file ? Omnibus::Overrides.overrides : {}

    expand_software(overrides, software_files)
  end

  # Creates some additional Rake tasks beyond those generated in the
  # process of reading in the DSL files.
  #
  # @param config [Omnibus::Config]
  # @return [void]
  #
  # @todo Not so sure I like how this is being done, but at least it
  #   isolates the Rake stuff.
  def self.generate_extra_rake_tasks(config)
    require 'omnibus/clean_tasks'

    if config.use_s3_caching
      require 'omnibus/s3_tasks'
    end
  end

  # Return a list of all the Ruby files (i.e., those with an "rb"
  # extension) in the given directory
  #
  # @param dir [String]
  # @return [Array<String>]
  def self.ruby_files(dir)
    Dir.glob("#{dir}/*.rb")
  end

  # Retrieve the fully-qualified paths to every software definition
  # file bundled in the {https://github.com/opscode/omnibus-software omnibus-software} gem.
  #
  # @return [Array<String>] the list of paths. Will be empty if the
  #   `omnibus-software` gem is not in the gem path.
  def self.omnibus_software_files
    if omnibus_software_root
      Dir.glob(File.join(omnibus_software_root, 'config', 'software', '*.rb'))
    else
      []
    end
  end

  # Given a list of software definitions from `omnibus-software` itself, and a
  # list of software files local to the current project, create a
  # single list of software definitions.  If the software was defined
  # in both sets, the locally-defined one ends up in the final list.
  #
  # The base name of the software file determines what software it
  # defines.
  #
  # @param omnibus_files [Array<String>]
  # @param local_files [Array<String>]
  # @return [Array<String>]
  def self.prefer_local_software(omnibus_files, local_files)
    base = software_map(omnibus_files)
    local = software_map(local_files)
    base.merge(local).values
  end

  # Given a list of file paths, create a map of the basename (without
  # extension) to the complete path.
  #
  # @param files [Array<String>]
  # @return [Hash<String, String>]
  def self.software_map(files)
    files.each_with_object({}) do |file, collection|
      software_name = File.basename(file, ".*")
      collection[software_name] = file
    end
  end
end
