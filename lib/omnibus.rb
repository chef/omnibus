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

require "omnibus/core_extensions"

require "cleanroom"
require "pathname"

require "omnibus/exceptions"
require "omnibus/version"

module Omnibus
  #
  # The path to the default configuration file.
  #
  # @return [String]
  #
  DEFAULT_CONFIG = "omnibus.rb".freeze

  autoload :Builder,          "omnibus/builder"
  autoload :BuildVersion,     "omnibus/build_version"
  autoload :BuildVersionDSL,  "omnibus/build_version_dsl"
  autoload :Cleaner,          "omnibus/cleaner"
  autoload :Compressor,       "omnibus/compressor"
  autoload :Config,           "omnibus/config"
  autoload :Digestable,       "omnibus/digestable"
  autoload :Error,            "omnibus/exceptions"
  autoload :Fetcher,          "omnibus/fetcher"
  autoload :FileSyncer,       "omnibus/file_syncer"
  autoload :Generator,        "omnibus/generator"
  autoload :GitCache,         "omnibus/git_cache"
  autoload :HealthCheck,      "omnibus/health_check"
  autoload :Stripper,         "omnibus/stripper"
  autoload :Instrumentation,  "omnibus/instrumentation"
  autoload :Library,          "omnibus/library"
  autoload :Logger,           "omnibus/logger"
  autoload :Logging,          "omnibus/logging"
  autoload :Metadata,         "omnibus/metadata"
  autoload :NullArgumentable, "omnibus/null_argumentable"
  autoload :Ohai,             "omnibus/ohai"
  autoload :Package,          "omnibus/package"
  autoload :Packager,         "omnibus/packager"
  autoload :Project,          "omnibus/project"
  autoload :Publisher,        "omnibus/publisher"
  autoload :Reports,          "omnibus/reports"
  autoload :S3Cache,          "omnibus/s3_cache"
  autoload :Software,         "omnibus/software"
  autoload :Sugarable,        "omnibus/sugarable"
  autoload :Templating,       "omnibus/templating"
  autoload :ThreadPool,       "omnibus/thread_pool"
  autoload :Util,             "omnibus/util"
  autoload :Licensing,        "omnibus/licensing"

  autoload :GitFetcher,  "omnibus/fetchers/git_fetcher"
  autoload :NetFetcher,  "omnibus/fetchers/net_fetcher"
  autoload :NullFetcher, "omnibus/fetchers/null_fetcher"
  autoload :PathFetcher, "omnibus/fetchers/path_fetcher"

  autoload :ArtifactoryPublisher, "omnibus/publishers/artifactory_publisher"
  autoload :NullPublisher,        "omnibus/publishers/null_publisher"
  autoload :S3Publisher,          "omnibus/publishers/s3_publisher"

  autoload :Manifest,      "omnibus/manifest"
  autoload :ManifestEntry, "omnibus/manifest_entry"
  autoload :ManifestDiff,  "omnibus/manifest_diff"

  autoload :ChangeLog, "omnibus/changelog"
  autoload :GitRepository, "omnibus/git_repository"

  autoload :SemanticVersion, "omnibus/semantic_version"

  module Command
    autoload :Base,    "omnibus/cli/base"
    autoload :Cache,   "omnibus/cli/cache"
    autoload :Publish, "omnibus/cli/publish"
    autoload :ChangeLog, "omnibus/cli/changelog"
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
      # Clear caches on Project and Software
      Project.reset!
      Software.reset!
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

    #
    # Load in an Omnibus configuration file.  Values will be merged with
    # and override the defaults defined in {Config}.
    #
    # @param [String] file path to a configuration file to load
    #
    # @return [void]
    #
    def load_configuration(file)
      Config.load(file)
    end

    #
    # Locate an executable in the current $PATH.
    #
    # @return [String, nil]
    #   the path to the executable, or +nil+ if not present
    #
    def which(executable)
      if File.file?(executable) && File.executable?(executable)
        executable
      elsif ENV["PATH"]
        path = ENV["PATH"].split(File::PATH_SEPARATOR).find do |path|
          File.executable?(File.join(path, executable))
        end

        path && File.expand_path(executable, path)
      end
    end

    #
    # All {Project} instances that have been loaded.
    #
    # @return [Array<:Project>]
    #
    def projects
      project_map.map do |name, _|
        Project.load(name)
      end
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
      Project.load(name)
    end

    #
    # The source root is the path to the root directory of the `omnibus` gem.
    #
    # @return [Pathname]
    #
    def source_root
      @source_root ||= Pathname.new(File.expand_path("../..", __FILE__))
    end

    #
    # The preferred filepath to a project with the given name on disk.
    #
    # @return [String, nil]
    #
    def project_path(name)
      project_map[name.to_s]
    end

    #
    # The preferred filepath to a software with the given name on disk.
    #
    # @return [String, nil]
    #
    def software_path(name)
      software_map[name.to_s]
    end

    #
    # The list of directories to search for the given +path+. These paths are
    # returned **in order** of specificity.
    #
    # @param [String] path
    #   the subpath to search for
    #
    # @return [Array<String>]
    #
    def possible_paths_for(path)
      possible_paths[path] ||= [
        paths_from_project_root,
        paths_from_local_software_dirs,
        paths_from_software_gems,
      ].flatten.inject([]) do |array, directory|
        destination = File.join(directory, path)

        if File.directory?(destination)
          array << destination
        end

        array
      end
    end

    private

    #
    # The list of possible paths, cached as a hash for quick lookup.
    #
    # @see {Omnibus.possible_paths_for}
    #
    # @return [Hash]
    #
    def possible_paths
      @possible_paths ||= {}
    end

    #
    # Map the given file paths to the basename of their file, with the +.rb+
    # extension removed.
    #
    # @example
    #   { 'foo' => '/path/to/foo' }
    #
    # @return [Hash<String, String>]
    #
    def basename_map(paths)
      paths.inject({}) do |hash, directory|
        Dir.glob("#{directory}/*.rb").each do |path|
          name = File.basename(path, ".rb")
          hash[name] ||= path
        end

        hash
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
      @software_map ||= basename_map(possible_paths_for(Config.software_dir))
    end

    #
    # A hash of all projects (by name) and their respective path on disk. These
    # files are **in order**, meaning the project path is the **first**
    # occurrence of the project in the list. If the same project is
    # encountered a second time, it will be skipped.
    #
    # @example
    #   { 'chefdk' => '/home/omnibus/project/config/projects/chefdk.rb' }
    #
    # @return [Hash<String, String>]
    #
    def project_map
      @project_map ||= basename_map(possible_paths_for(Config.project_dir))
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
      @paths_from_project_root ||=
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
      @paths_from_local_software_dirs ||=
        Array(Config.local_software_dirs).inject([]) do |array, path|
          fullpath = File.expand_path(path, Config.project_root)

          if File.directory?(fullpath)
            array << fullpath
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
      @paths_from_software_gems ||=
        Array(Config.software_gems).inject([]) do |array, name|
          if (spec = Gem::Specification.find_all_by_name(name).first)
            array << File.expand_path(spec.gem_dir)
          end

          array
        end
    end
  end
end
