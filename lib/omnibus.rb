#
# Copyright 2012-2014 Chef Software, Inc.
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

require 'pathname'
require 'json'

require 'omnibus/exceptions'
require 'omnibus/version'

module Omnibus
  #
  # The path to the default configuration file.
  #
  # @return [String]
  #
  DEFAULT_CONFIG = 'omnibus.rb'.freeze

  autoload :Builder,          'omnibus/builder'
  autoload :BuildVersion,     'omnibus/build_version'
  autoload :BuildVersionDSL,  'omnibus/build_version_dsl'
  autoload :Cleaner,          'omnibus/cleaner'
  autoload :Cleanroom,        'omnibus/cleanroom'
  autoload :Config,           'omnibus/config'
  autoload :Digestable,       'omnibus/digestable'
  autoload :Error,            'omnibus/exceptions'
  autoload :Fetcher,          'omnibus/fetcher'
  autoload :Generator,        'omnibus/generator'
  autoload :GitCache,         'omnibus/git_cache'
  autoload :HealthCheck,      'omnibus/health_check'
  autoload :Library,          'omnibus/library'
  autoload :Logger,           'omnibus/logger'
  autoload :Logging,          'omnibus/logging'
  autoload :NullArgumentable, 'omnibus/null_argumentable'
  autoload :NullBuilder,      'omnibus/null_builder'
  autoload :Ohai,             'omnibus/ohai'
  autoload :Package,          'omnibus/package'
  autoload :Project,          'omnibus/project'
  autoload :Publisher,        'omnibus/publisher'
  autoload :Reports,          'omnibus/reports'
  autoload :S3Cache,          'omnibus/s3_cache'
  autoload :Software,         'omnibus/software'
  autoload :Sugarable,        'omnibus/sugarable'
  autoload :Util,             'omnibus/util'

  # @todo Remove this in the next major release
  autoload :OHAI, 'omnibus/ohai'

  autoload :GitFetcher,     'omnibus/fetchers/git_fetcher'
  autoload :NetFetcher,     'omnibus/fetchers/net_fetcher'
  autoload :PathFetcher,    'omnibus/fetchers/path_fetcher'
  autoload :S3CacheFetcher, 'omnibus/fetchers/s3_cache_fetcher'

  autoload :ArtifactoryPublisher, 'omnibus/publishers/artifactory_publisher'
  autoload :NullPublisher,        'omnibus/publishers/null_publisher'
  autoload :S3Publisher,          'omnibus/publishers/s3_publisher'

  module Command
    autoload :Base,    'omnibus/cli/base'
    autoload :Cache,   'omnibus/cli/cache'
    autoload :Publish, 'omnibus/cli/publish'
  end

  module Packager
    autoload :Base,       'omnibus/packagers/base'
    autoload :MacDmg,     'omnibus/packagers/mac_dmg'
    autoload :MacPkg,     'omnibus/packagers/mac_pkg'
    autoload :WindowsMsi, 'omnibus/packagers/windows_msi'
  end

  class << self
    #
    # Reset the current Omnibus configuration. This is primary an internal API
    # used in testing, but it can also be useful when Omnibus is used as a
    # library.
    #
    # Note - this persists the +Logger+ object by default.
    #
    # @param [true, false] include_logger
    #   whether the logger object should be cleared as well
    #
    # @return [void]
    #
    def reset!(include_logger = false)
      instance_variables.each do |instance_variable|
        unless include_logger
          next if instance_variable == :@logger
        end

        remove_instance_variable(instance_variable)
      end

      Config.reset!
    end

    #
    # The logger for this Omnibus instance.
    #
    # @example
    #   Omnibus.logger.debug { 'This is a message!' }
    #
    # @return [Logger]
    #
    def logger
      @logger ||= Logger.new
    end

    #
    # @api private
    #
    # Programatically set the logger for Omnibus.
    #
    # @param [Logger] logger
    #
    def logger=(logger)
      @logger = logger
    end

    #
    # The UI class for Omnibus.
    #
    # @return [Thor::Shell]
    #
    def ui
      @ui ||= Thor::Base.shell.new
    end

    # Convenience method for access to the {Config} object.
    # Provided for backward compatibility.
    #
    # @return [Config]
    #
    # @deprecated Just refer to {Config} directly.
    def config
      Omnibus.logger.deprecated('Omnibus') do
        'Omnibus.config. Please use Config.(thing) instead.'
      end

      Config
    end

    # Load in an Omnibus configuration file.  Values will be merged with
    # and override the defaults defined in {Config}.
    #
    # @param [String] file path to a configuration file to load
    #
    # @return [void]
    def load_configuration(file)
      Config.load(file)
    end

    # Processes the configuration to construct the dependency tree of
    # projects and software.
    #
    # @return [void]
    def process_configuration
      process_dsl_files
    end

    #
    # All {Project} instances that have been loaded.
    #
    # @return [Array<:Project>]
    #
    def projects
      _projects.values
    end

    #
    # Load the {Project} instance with the given name.
    #
    # @param [String] name
    #   the name of the project to get
    #
    # @return [Project]
    #
    def project(name)
      _projects[name.to_s]
    end

    #
    # The absolute path to the Omnibus project/reository directory.
    #
    # @deprecated Use {Config.project_root} instead.
    #
    # @return [String]
    #
    def project_root
      Omnibus.logger.deprecated('Omnibus') do
        'Omnibus.project_root. Please use Config.project_root instead.'
      end

      Config.project_root
    end

    #
    # Backward compat alias.
    #
    # @deprecated Use {Config.project_root} instead.
    #
    # @see (Omnibus.project_root)
    #
    def root
      Omnibus.logger.deprecated('Omnibus') do
        'Omnibus.root. Please use Omnibus.project_root instead.'
      end

      Config.project_root
    end

    #
    # The source root is the path to the root directory of the `omnibus` gem.
    #
    # @return [Pathname]
    #
    def source_root
      @source_root ||= Pathname.new(File.expand_path('../..', __FILE__))
    end

    # Processes all configured {Omnibus::Project} and
    # {Omnibus::Software} DSL files.
    #
    # @return [void]
    def process_dsl_files
      expand_software
    end

    #
    # The list of directories to search for {Software} files. These paths are
    # returned **in order** of specifity.
    #
    # @see (Config#project_root)
    # @see (Config#software_dir)
    # @see (Config#software_gems)
    # @see (Config#local_software_dirs)
    #
    # @return [Array<String>]
    #
    def software_dirs
      directories = [
        paths_from_project_root,
        paths_from_local_software_dirs,
        paths_from_software_gems,
      ].flatten

      directories.inject([]) do |array, directory|
        softwares_path = File.join(directory, Config.software_dir)

        if File.directory?(softwares_path)
          array << softwares_path
        else
          Omnibus.logger.warn('Omnibus') do
            "`#{directory}' does not contain a valid directory structure. " \
            "Does it contain a folder at `#{Config.software_dir}'?"
          end
        end

        array
      end
    end

    #
    # A hash of all softwares (by name) and their respective path on disk. These
    # files are **in order**, meaning the software path is the **first**
    # occurrence of the software in the list. If the same software is
    # encountered a second time, it will be skipped.
    #
    # @example
    #   { 'preparation' => '/home/omnibus/project/config/software/preparation.rb' }
    #
    # @return [Hash<String, String>]
    #
    def software_map
      software_dirs.inject({}) do |hash, directory|
        Dir.glob("#{directory}/*.rb").each do |path|
          name = File.basename(path, '.rb')

          if hash[name].nil?
            Omnibus.logger.info('Omnibus#software_map') do
              "Using software `#{name}' from `#{path}'."
            end

            hash[name] = path
          else
            Omnibus.logger.debug('Omnibus#software_map') do
              "Skipping software `#{name}' because it was loaded from an " \
              "earlier path."
            end
          end
        end

        hash
      end
    end

    private

    #
    # @api private
    #
    # The list of omnibus projects. This is an internal API that maps a
    # project's name to the actual project object.
    #
    # @return [Hash<String, Project>]
    #
    def _projects
      return @_projects if @_projects

      path = File.expand_path(Config.project_dir, Config.project_root)
      @_projects = Dir.glob("#{path}/*.rb").inject({}) do |hash, path|
        name = File.basename(path, '.rb')

        if hash[name].nil?
          Omnibus.logger.info('Omnibus#projects') do
            "Using project `#{name}' from `#{path}'."
          end

          hash[name] = Project.load(path)
        else
          Omnibus.logger.debug('Omnibus#projects') do
            "Skipping project `#{name}' because it was already loaded."
          end
        end

        hash
      end

      @_projects
    end

    #
    # The list of all software paths to software from the project root. This is
    # always a single value, but an array is returned for consistency with the
    # other +software_paths_*+ methods.
    #
    # @see (Config#project_root)
    # @see (Config#software_dir)
    #
    # @return [Array<String>]
    #
    def paths_from_project_root
      [Config.project_root]
    end

    #
    # The list of all software paths on disk to software files. If relative
    # paths are given, they are expanded relative to {Config#project_root}.
    #
    # @see (Config#local_software_dirs)
    #
    # @return [Array<String>]
    #
    def paths_from_local_software_dirs
      Array(Config.local_software_dirs).inject([]) do |array, path|
        fullpath = File.expand_path(path, Config.project_root)

        if File.directory?(fullpath)
          array << fullpath
        else
          Omnibus.logger.warn('Omnibus') do
            "Could not load softwares from path `#{fullpath}'. Does it exist?"
          end
        end

        array
      end
    end

    #
    # The list of software paths from within the list of gems. These gems paths
    # are loaded from disk using +Gem::Specification+. The latest version of
    # the gem on disk is loaded. For this reason, it is recommended that you
    # add these gems to your bundle and be nice to your co-workers.
    #
    # @see (Config#software_gems)
    #
    # @return [Array<String>]
    #
    def paths_from_software_gems
      Array(Config.software_gems).inject([]) do |array, name|
        if (spec = Gem::Specification.find_all_by_name(name).first)
          array << File.expand_path(spec.gem_dir)
        else
          Omnibus.logger.warn('Omnibus') do
            "Could not load softwares from gem `#{name}'. Is it installed?"
          end
        end

        array
      end
    end

    #
    # Generate {Software} objects for all software DSL files in
    # +software_specs+.
    #
    # @return [void]
    #
    def expand_software
      Omnibus.projects.each do |project|
        project.dependencies.each do |dependency|
          recursively_load_dependency(dependency, project)
        end
      end
    end

    #
    # Loads a project's dependencies recursively, ensuring all transitive
    # dependencies are also loaded in the correct order.
    #
    # @param [String] dependency
    #   the name of the dependency
    # @param [Project] project
    #   the project that loaded the software
    #
    # @return [void]
    #
    def recursively_load_dependency(dependency, project)
      filepath = software_map[dependency]

      if filepath.nil?
        raise MissingProjectDependency.new(dependency, software_dirs)
      end

      software = Software.load(project, filepath)

      # load any transitive deps for the component into the library also
      software.dependencies.each do |transitive_dependency|
        recursively_load_dependency(transitive_dependency, project)
      end

      project.library.component_added(software)
    end
  end
end
