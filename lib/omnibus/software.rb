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

require 'digest/md5'
require 'mixlib/shellout'
require 'net/ftp'
require 'net/http'
require 'net/https'
require 'uri'

require 'omnibus/fetcher'
require 'omnibus/builder'
require 'omnibus/config'

require 'fileutils'

module Omnibus
  # Omnibus software DSL reader
  class Software
    NULL_ARG = Object.new
    UNINITIALIZED = Object.new

    # It appears that this is not used
    attr_reader :builder

    # @todo Why do we apparently use two different ways of
    #   implementing what are effectively the same DSL methods?  Compare
    #   with Omnibus::Project.
    attr_reader :description

    # @todo This doesn't appear to be used at all
    attr_reader :fetcher

    attr_reader :project

    attr_reader :version

    attr_reader :overrides

    attr_reader :whitelist_files

    def self.load(filename, project, repo_overrides = {})
      new(IO.read(filename), filename, project, repo_overrides)
    end

    # @param io [String]
    # @param filename [String]
    # @param project [???] Is this a string or an Omnibus::Project?
    # @param repo_overrides [Hash]
    #
    # @see Omnibus::Overrides
    #
    # @todo See comment on {Omnibus::NullBuilder}
    # @todo does `filename` need to be absolute, or does it matter?
    # @ @todo Any reason to not have this just take a filename,
    #   project, and override hash directly?  That is, why io AND a
    #   filename, if the filename can always get you the contents you
    #   need anyway?
    def initialize(io, filename, project, repo_overrides = {})
      @version          = nil
      @overrides        = UNINITIALIZED
      @name             = nil
      @description      = nil
      @source           = nil
      @relative_path    = nil
      @source_uri       = nil
      @source_config    = filename
      @project          = project
      @always_build     = false
      @repo_overrides   = repo_overrides

      # Seems like this should just be Builder.new(self) instead
      @builder = NullBuilder.new(self)

      @dependencies = []
      @whitelist_files = []
      instance_eval(io, filename, 0)
    end

    # Retrieves the override_version
    #
    # @return [Hash]
    #
    # @todo: can't we just use #version here or are we testing this against nil? somewhere and
    #        not using #overridden?
    def override_version
      $stderr.puts 'The #override_version is DEPRECATED, please use #version or test with #overridden?'
      overrides[:version]
    end

    # Retrieves the repo-level and project-level overrides for the software.
    #
    # @return [Hash]
    def overrides
      # deliberately not providing a setter since that feels like a shotgun pointed at a foot
      if @overrides == UNINITIALIZED
        # lazily initialized because we need the 'name' to be parsed first
        @overrides = {}
        @overrides = project.overrides[name.to_sym].dup if project.overrides[name.to_sym]
        if @repo_overrides[name]
          @overrides[:version] = @repo_overrides[name]
        end
      end
      @overrides
    end

    # Sets or retreives the name of the software
    #
    # @param val [String] name of the Software
    # @return [String]
    def name(val = NULL_ARG)
      @name = val unless val.equal?(NULL_ARG)
      @name || fail(MissingSoftwareConfiguration.new(name, 'name', 'libxslt'))
    end

    # Sets the description of the software
    #
    # @param val [String] description of the Software
    # @return [void]
    def description(val)
      @description = val
    end

    # Add an Omnibus software dependency.
    #
    # @param val [String] the name of a Software dependency
    # @return [void]
    def dependency(val)
      @dependencies << val
    end

    # Set or retrieve the list of software dependencies for this
    # project.  As this is a DSL method, only pass the names of
    # software components, not {Omnibus::Software} objects.
    #
    # These is the software that comprises your project, and is
    # distinct from runtime dependencies.
    #
    # @note This will reinitialize the internal depdencies Array
    #   and overwrite any dependencies that may have been set using
    #   {#dependency}.
    #
    # @param val [Array<String>] a list of names of Software components
    # @return [Array<String>]
    def dependencies(val = NULL_ARG)
      @dependencies = val unless val.equal?(NULL_ARG)
      @dependencies
    end

    # Set or retrieve the source for the software
    #
    # @param val [Hash<Symbol, String>] a single key/pair that defines
    #   the kind of source and a path specifier
    # @option val [String] :git (nil) a Git URL
    # @option val [String] :url (nil) a general URL
    # @option val [String] :path (nil) a fully-qualified local file system path
    #
    # @todo Consider changing this to accept two arguments instead
    # @todo This should throw an error if an invalid key is given, or
    #   if more than one pair is given
    def source(val = NULL_ARG)
      unless val.equal?(NULL_ARG)
        @source ||= {}
        @source.merge!(val)
      end
      apply_overrides(:source)
    end

    # Retieve the default_version of the software
    #
    # @return [String]
    #
    # @todo: remove this in favor of default_version
    def given_version
      $stderr.puts "Getting the default version via #given_version is DEPRECATED, please use 'default_version'"
      default_version
    end

    # Set or retieve the default_version of the software to build
    #
    # @param val [String]
    # @return [String]
    def default_version(val = NULL_ARG)
      @version = val unless val.equal?(NULL_ARG)
      @version
    end

    # Evaluate a block only if the version matches.
    #
    # Note that passing only a string without a block will set the default_version but this
    # behavior is deprecated and will be removed, use the default_version method instead.
    #
    # @param val [String] version of the software.
    # @param block [Proc] block to run if the version we are building matches the argument.
    # @return [void]
    #
    # @todo remove deprecated setting of version
    def version(val = NULL_ARG)
      if block_given?
        if val.equal?(NULL_ARG)
          fail 'block needs a version argument to apply against'
        else
          if val == apply_overrides(:version)
            yield
          end
        end
      else
        unless val.equal?(NULL_ARG)
          $stderr.puts "Setting the version via 'version' is DEPRECATED, please use 'default_version'"
          @version = val
        end
      end
      apply_overrides(:version)
    end

    # Add an Omnibus software dependency.
    #
    # @param file [String, Regexp] the name of a file to ignore in the healthcheck
    # @return [void]
    def whitelist_file(file)
      file = Regexp.new(file) unless file.kind_of?(Regexp)
      @whitelist_files << file
    end

    # Was this software version overridden externally, relative to the
    # version declared within the software DSL file?
    #
    # @return [Boolean]
    def overridden?
      # note: using instance variables to bypass accessors that enforce overrides
      @overrides.key?(:version) && (@overrides[:version] != @version)
    end

    # @todo see comments on {Omnibus::Fetcher#without_caching_for}
    def version_guid
      Fetcher.for(self).version_guid
    end

    # @todo Define as a delegator
    def build_version
      @project.build_version
    end

    # @todo Judging by existing usage, this should sensibly default to
    #   the name of the software, since that's what it effectively does down in #project_dir
    def relative_path(val)
      @relative_path = val
    end

    # @todo Code smell... this only has meaning if the software was
    #   defined with a :uri, and this is only used in
    #   {Omnibus::NetFetcher}.  This responsibility is distributed
    #   across two classes, one of which is a specific interface
    #   implementation
    # @todo Why the caching of the URI?
    def source_uri
      @source_uri ||= URI(@source[:url])
    end

    # @param val [Boolean]
    # @return void
    #
    # @todo Doesn't necessarily need to be a Boolean if #always_build?
    #   uses !! operator
    def always_build(val)
      @always_build = val
    end

    # @return [Boolean]
    def always_build?
      return true if project.dirty_cache
      # Should do !!(@always_build)
      @always_build
    end

    # @todo Code smell... this only has meaning if the software was
    #   defined with a :uri, and this is only used in
    #   {Omnibus::NetFetcher}.  This responsibility is distributed
    #   across two classes, one of which is a specific interface
    #   implementation
    def checksum
      @source[:md5]
    end

    # @todo Should this ever be legitimately used in the DSL?  It
    #   seems that that facility shouldn't be provided, and thus this
    #   should be made a private function (if it even really needs to
    #   exist at all).
    def config
      Omnibus.config
    end

    # @!group Directory Accessors

    def source_dir
      config.source_dir
    end

    def cache_dir
      config.cache_dir
    end

    # The directory that the software will be built in
    #
    # @return [String] an absolute filesystem path
    def build_dir
      "#{config.build_dir}/#{@project.name}"
    end

    # @todo Why the different name (i.e. *_dir instead of *_path, or
    #   vice versa?)  Given the patterns that are being set up
    #   elsewhere, this is just confusing inconsistency.
    def install_dir
      @project.install_path
    end

    # @!endgroup

    # @todo It seems like this isn't used, and if it were, it should
    # probably be part of Opscode::Builder instead
    def max_build_jobs
      if OHAI.cpu && OHAI.cpu[:total] && OHAI.cpu[:total].to_s =~ /^\d+$/
        OHAI.cpu[:total].to_i + 1
      else
        3
      end
    end

    # @todo See comments for {#source_uri}... same applies here.  If
    #   this is called in a non-source-software context, bad things will
    #   happen.
    def project_file
      filename = source_uri.path.split('/').last
      "#{cache_dir}/#{filename}"
    end

    # @todo this would be simplified and clarified if @relative_path
    #   defaulted to @name... see the @todo tag for #relative_path
    # @todo Move this up with the other *_dir methods for better
    #   logical grouping
    def project_dir
      @relative_path ? "#{source_dir}/#{@relative_path}" : "#{source_dir}/#{@name}"
    end

    # The name of the sentinel file that marks the most recent fetch
    # time of the software
    #
    # @return [String] an absolute path
    #
    # @see Omnibus::Fetcher
    # @todo seems like this should be a private
    #   method, since it's an implementation detail.
    def fetch_file
      "#{build_dir}/#{@name}.fetch"
    end

    # @todo This is actually "snake case", not camel case
    # @todo this should be a private method
    def camel_case_path(project_path)
      path = project_path.dup
      # split the path and remmove and empty strings
      if platform == 'windows'
        path.sub!(':', '')
        parts = path.split('\\') - ['']
        parts.join('_')
      else
        parts = path.split('/') - ['']
        parts.join('_')
      end
    end

    # Define a series of {Omnibus::Builder} DSL commands that are
    # required to successfully build the software.
    #
    # @param block [block] a block of build commands
    # @return void
    #
    # @see Omnibus::Builder
    #
    # @todo Not quite sure the proper way to document a "block"
    #   parameter in Yard
    # @todo Seems like this renders the setting of @builder in the
    #   initializer moot
    # @todo Rename this to something like "build_commands", since it
    #   doesn't actually do any building
    def build(&block)
      @builder = Builder.new(self, &block)
    end

    # Returns the platform of the machine on which Omnibus is running,
    # as determined by Ohai.
    #
    # @return [String]
    def platform
      OHAI.platform
    end

    # Return the architecture of the machine, as determined by Ohai.
    # @return [String] Either "sparc" or "intel", as appropriate
    # @todo Is this used?  Doesn't appear to be...
    def architecture
      OHAI.kernel['machine'] =~ /sun/ ? 'sparc' : 'intel'
    end

    # Actually build the software package
    def build_me
      # Fetch the source
      fetcher = fetch_me

      # Build if we need to
      if always_build?
        execute_build(fetcher)
      else
        if Omnibus::InstallPathCache.new(install_dir, self).restore
          true
        else
          execute_build(fetcher)
        end
      end
      true
    end

    # Fetch the software
    def fetch_me
      # Create the directories we need
      [build_dir, source_dir, cache_dir, project_dir].each do |dir|
        FileUtils.mkdir_p dir
      end

      fetcher = Fetcher.for(self)

      if !File.exist?(fetch_file) || fetcher.fetch_required?
        # force build to run if we need to do an updated fetch
        fetcher.fetch
        touch fetch_file
      end

      fetcher
    end

    private

    # Apply overrides in the @overrides hash that mask instance variables
    # that are set by parsing the DSL
    #
    def apply_overrides(attr)
      val = instance_variable_get(:"@#{attr}")
      if val.is_a?(Hash) || overrides[attr].is_a?(Hash)
        val ||= {}
        override = overrides[attr] || {}
        val.merge(override)
      else
        overrides[attr] || val
      end
    end

    # @todo What?!
    # @todo It seems that this is not used... remove it
    # @deprecated Use something else (?)
    def command(*args)
      fail 'Method Moved.'
    end

    def execute_build(fetcher)
      fetcher.clean
      @builder.build
      puts "[software:#{name}] caching build"
      Omnibus::InstallPathCache.new(install_dir, self).incremental
      puts "[software:#{name}] has dirtied the cache"
      project.dirty_cache = true
    end

    def touch(file)
      File.open(file, 'w') do |f|
        f.print ''
      end
    end
  end
end
