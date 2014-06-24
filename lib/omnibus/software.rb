#
# Copyright 2012 Chef Software, Inc.
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

require 'fileutils'
require 'uri'

module Omnibus
  # Omnibus software DSL reader
  class Software
    class << self
      #
      # @param [Project] project
      #   the project that loaded this software definition
      # @param [String] filepath
      #   the path to the software definition to load from disk
      # @param [hash] overrides
      #   a list of software overrides
      #
      # @return [Software]
      #
      def load(project, filepath, overrides = {})
        instance = new(project, overrides, filepath)
        instance.evaluate_file(filepath)
        instance
      end
    end

    include Cleanroom
    include Logging
    include Nullable
    include Sugarable

    #
    # Create a new software object.
    #
    # @param [String] NullBuilder.new(self)
    # @param [Project] project
    #   the Omnibus project that instantiated this software definition
    # @param [Hash] repo_overrides
    #   @see Omnibus::Overrides
    # @param [String] filepath
    #   the path to where this software definition lives on disk
    #
    # @return [Software]
    #
    def initialize(project, repo_overrides = {}, filepath = nil)
      unless project.is_a?(Project)
        raise ArgumentError,
          "`project' must be a kind of `Omnibus::Project', but was `#{project.class.inspect}'!"
      end

      # Magical methods
      @filepath = filepath
      @project  = project

      # Overrides
      @overrides      = NULL
      @repo_overrides = repo_overrides
    end

    #
    # The builder for this softare. This defaults to a {NullBuilder}, but
    # can be specified using the {#build} DSL method.
    #
    # @return [Builder]
    #
    def builder
      @builder ||= NullBuilder.new(self)
    end

    #
    # Compare two software projects (by name).
    #
    # @return [1, 0, -1]
    #
    def <=>(other)
      self.name <=> other.name
    end

    #
    # @!group DSL methods
    #
    # The following DSL methods are available from within software definitions.
    # --------------------------------------------------

    #
    # The project that created this software.
    #
    # @return [Project]
    #
    def project
      @project
    end
    expose :project

    #
    # Retrieves the overriden version.
    #
    # @deprecated Use {#version} or test with {#overridden?} instead.
    #
    # @return [Hash]
    #
    def override_version
      log.deprecated(log_key) do
        'Software#override_version. Please use #version or ' \
        'test with #overridden?'
      end

      overrides[:version]
    end
    expose :override_version

    #
    # **[Required]** Sets or retreives the name of the software.
    #
    # @example
    #   name 'libxslt'
    #
    # @param [String] val
    #   name of the Software
    #
    # @return [String]
    #
    def name(val = NULL)
      if null?(val)
        @name || raise(MissingSoftwareConfiguration.new(name, 'name', 'libxslt'))
      else
        @name = val
      end
    end
    expose :name

    #
    # Sets the description of the software.
    #
    # @example
    #   description 'Installs libxslt'
    #
    # @param [String] val
    #   the description of the software
    #
    # @return [String]
    #
    def description(val = NULL)
      if null?(val)
        @description
      else
        @description = val
      end
    end
    expose :description

    #
    # Always build the given software definition.
    #
    # @param [true, false] val
    #
    # @return [true, false]
    #
    def always_build(val)
      @always_build = val
      @always_build
    end
    expose :always_build

    #
    # Add a software dependency to this software.
    #
    # @example
    #   dependency 'libxml2'
    #   dependency 'libpng'
    #
    # @param [String] val
    #   the name of a software dependency
    #
    # @return [Array<String>]
    #   the list of current dependencies
    #
    def dependency(val)
      dependencies << val
      dependencies.dup
    end
    expose :dependency

    #
    # Set or retrieve the source for the software.
    #
    # @raise [InvalidValue]
    #   if the parameter is not a Hash
    # @raise [InvalidValue]
    #   if the hash includes extraneous keys
    # @raise [InvalidValue]
    #   if the hash declares keys that cannot work together
    #   (like +:git+ and +:path+)
    #
    # @example
    #   source url: 'http://ftp.gnu.org/gnu/autoconf/autoconf-2.68.tar.gz',
    #          md5: 'c3b5247592ce694f7097873aa07d66fe'
    #
    # @param [Hash<Symbol, String>] val
    #   a single key/pair that defines the kind of source and a path specifier
    #
    # @option val [String] :git (nil)
    #   a git URL
    # @option val [String] :url (nil)
    #   general URL
    # @option val [String] :path (nil)
    #   a fully-qualified local file system path
    # @option val [String] :md5 (nil)
    #   the checksum of the downloaded artifact
    #
    # @return [Hash]
    #
    def source(val = NULL)
      unless null?(val)
        unless val.is_a?(Hash)
          raise InvalidValue.new(:source,
            "be a kind of `Hash', but was `#{val.class.inspect}'")
        end

        extra_keys = val.keys - [:git, :path, :url, :md5]
        unless extra_keys.empty?
          raise InvalidValue.new(:source,
            "only include valid keys. Invalid keys: #{extra_keys.inspect}")
        end

        duplicate_keys = val.keys & [:git, :path, :url]
        unless duplicate_keys.size < 2
          raise InvalidValue.new(:source,
            "not include duplicate keys. Duplicate keys: #{duplicate_keys.inspect}")
        end

        @source ||= {}
        @source.merge!(val)
      end

      apply_overrides(:source)
    end
    expose :source

    #
    # Set or retieve the {#default_version} of the software to build.
    #
    # @example
    #   default_version '1.2.3'
    #
    # @param [String] val
    #   the default version to set for the software
    #
    # @return [String]
    #
    def default_version(val = NULL)
      if null?(val)
        @version
      else
        @version = val
      end
    end
    expose :default_version

    #
    # Evaluate a block only if the version matches.
    #
    # @example
    #   version '1.2.3' do
    #     source path: '/local/path/to/software-1.2.3'
    #   end
    #
    # @deprecated passing only a string without a block to set the version is
    #   deprecated. Please use {#default_version} instead.
    #
    # @param [String] val
    #   the version of the software
    #
    # @param [Proc] block
    #   the block to run if the version we are building matches the argument
    #
    # @return [String, Proc]
    #
    def version(val = NULL)
      if block_given?
        if val.equal?(NULL)
          raise InvalidValue.new(:version,
            'pass a block when given a version argument')
        else
          if val == apply_overrides(:version)
            yield
          end
        end
      else
        unless val.equal?(NULL)
          log.deprecated(log_key) do
            'Software#version. Please use #default_version instead.'
          end
          @version = val
        end
      end

      apply_overrides(:version)
    end
    expose :version

    #
    # Add a file to the healthcheck whitelist.
    #
    # @example
    #   whitelist_file '/path/to/file'
    #
    # @param [String, Regexp] file
    #   the name of a file to ignore in the healthcheck
    #
    # @return [Array<String>]
    #   the list of currently whitelisted files
    #
    def whitelist_file(file)
      file = Regexp.new(file) unless file.kind_of?(Regexp)
      whitelist_files << file
      whitelist_files.dup
    end
    expose :whitelist_file

    #
    # The relative path inside the extracted tarball.
    #
    # @example
    #   relative_path 'example-1.2.3'
    #
    # @param [String] relative_path
    #   the relative path inside the tarball
    #
    # @return [String]
    #
    def relative_path(val = NULL)
      if null?(val)
        @relative_path ||= name
      else
        @relative_path = val
      end
    end
    expose :relative_path

    #
    # The path where the extracted software lives.
    #
    # @return [String]
    #
    def project_dir
      @project_dir ||= File.join(Config.source_dir, relative_path)
    end
    expose :project_dir

    #
    # The path where this software is installed on disk.
    #
    # @deprecated Use {#install_path} instead
    #
    # @return [String]
    #
    def install_dir
      log.deprecated(log_key) do
        'Software#install_dir. Please use #install_path instead.'
      end

      install_path
    end
    expose :install_dir

    #
    # The path where this software is installed on disk.
    #
    # @example
    #   { 'PATH' => "#{install_dir}/embedded/bin:#{ENV["PATH"]}", }
    #
    # @see Project#install_path
    #
    # @return [String]
    #
    def install_path
      @project.install_path
    end
    expose :install_path

    #
    # Returns the platform of the machine on which Omnibus is running, as
    # determined by Ohai.
    #
    # @deprecated Use +Ohai['platform']+ instead.
    #
    # @return [String]
    #
    def platform
      log.deprecated(log_key) do
        "Software#platform. Please use Ohai['platform'] instead."
      end

      Ohai['platform']
    end
    expose :platform

    #
    # Return the architecture of the machine, as determined by Ohai.
    #
    # @deprecated Will not be replaced.
    #
    # @return [String]
    #   Either "sparc" or "intel", as appropriate
    #
    def architecture
      log.deprecated(log_key) do
        "Software#architecture. Please use Ohai['kernel']['machine'] instead."
      end

      Ohai['kernel']['machine'] =~ /sun/ ? 'sparc' : 'intel'
    end
    expose :architecture

    #
    # Define a series of {Builder} DSL commands that are required to build the
    # software.
    #
    # @see Builder
    #
    # @param [Proc] block
    #   a block of build commands
    #
    # @return [Builder]
    #   the builder instance
    #
    # @todo Seems like this renders the setting of @builder in the initializer
    #   moot
    #
    def build(&block)
      @builder = Builder.new(self, &block)
      @builder
    end
    expose :build

    #
    # The source directory.
    #
    # @deprecated Use {Config.source_dir} instead
    #
    # @return [String]
    #
    def source_dir
      log.deprecated(log_key) do
        'source_dir (DSL). Please use Config.source_dir instead.'
      end

      Config.source_dir
    end
    expose :source_dir

    #
    # The cache directory.
    #
    # @deprecated Use {Config.cache_dir} instead
    #
    # @return [String]
    #
    def cache_dir
      log.deprecated(log_key) do
        'cache_dir (DSL). Please use Config.cache_dir instead.'
      end

      Config.cache_dir
    end
    expose :cache_dir

    #
    # Convenience method for accessing the global Omnibus configuration object.
    #
    # @deprecated Use {Config} instead
    #
    # @return Config
    #
    # @see Config
    #
    def config
      log.deprecated(log_key) do
        'config (DSL). Please use Config.(thing) instead (capital C).'
      end

      Config
    end
    expose :config

    #
    # @!endgroup
    # --------------------------------------------------

    #
    # @!group Public API
    #
    # In addition to the DSL methods, the following methods are considered to
    # be the "public API" for a software.
    # --------------------------------------------------

    #
    # The list of software dependencies for this project. These is the software
    # that comprises your project, and is distinct from runtime dependencies.
    #
    # @return [Array<String>]
    #
    def dependencies
      @dependencies ||= []
    end

    #
    # The list of files to ignore in the healthcheck.
    #
    # @return [Array<String>]
    #
    def whitelist_files
      @whitelist_files ||= []
    end

    #
    # The path (on disk) where this software came from. Warning: this can be
    # +nil+ if a software was dynamically created!
    #
    # @return [String, nil]
    #
    def filepath
      @filepath
    end

    #
    # The repo-level and project-level overrides for the software.
    #
    # @return [Hash]
    #
    def overrides
      if null?(@overrides)
        # lazily initialized because we need the 'name' to be parsed first
        @overrides = {}
        @overrides = project.overrides[name.to_sym].dup if project.overrides[name.to_sym]
        if @repo_overrides[name]
          @overrides[:version] = @repo_overrides[name]
        end
      end

      @overrides
    end

    #
    # Determine if this software version overridden externally, relative to the
    # version declared within the software DSL file?
    #
    # @return [true, false]
    #
    def overridden?
      # NOTE: using instance variables to bypass accessors that enforce overrides
      @overrides.key?(:version) && (@overrides[:version] != @version)
    end

    #
    # @!endgroup
    # --------------------------------------------------

    #
    # Retieve the {#default_version} of the software.
    #
    # @deprecated Use {#default_version} instead.
    #
    # @return [String]
    #
    def given_version
      log.deprecated(log_key) do
        'Software#given_version. Please use #default_version instead.'
      end

      default_version
    end

    # @todo see comments on {Omnibus::Fetcher#without_caching_for}
    def version_guid
      Fetcher.for(self).version_guid
    end

    # Returns the version to be used in cache.
    def version_for_cache
      if @fetcher
        @fetcher.version_for_cache || version
      else
        version
      end
    end

    # @todo Code smell... this only has meaning if the software was
    #   defined with a :uri, and this is only used in
    #   {Omnibus::NetFetcher}.  This responsibility is distributed
    #   across two classes, one of which is a specific interface
    #   implementation
    # @todo Why the caching of the URI?
    def source_uri
      @source_uri ||= URI(source[:url])
    end

    # @return [Boolean]
    def always_build?
      return true if project.dirty?
      !!@always_build
    end

    # @todo Code smell... this only has meaning if the software was
    #   defined with a :uri, and this is only used in
    #   {Omnibus::NetFetcher}.  This responsibility is distributed
    #   across two classes, one of which is a specific interface
    #   implementation
    def checksum
      source[:md5]
    end

    # @!group Directory Accessors

    # The directory that the software will be built in
    #
    # @return [String] an absolute filesystem path
    def build_dir
      "#{config.build_dir}/#{@project.name}"
    end

    # @!endgroup

    # @todo It seems like this isn't used, and if it were, it should
    # probably be part of Opscode::Builder instead
    def max_build_jobs
      if Ohai['cpu'] && Ohai['cpu']['total'] && Ohai['cpu']['total'].to_s =~ /^\d+$/
        Ohai['cpu']['total'].to_i + 1
      else
        3
      end
    end

    # @todo See comments for {#source_uri}... same applies here.  If
    #   this is called in a non-source-software context, bad things will
    #   happen.
    def project_file
      filename = source_uri.path.split('/').last
      "#{Config.cache_dir}/#{filename}"
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

    # Actually build the software package
    def build_me
      # Fetch the source
      @fetcher = fetch_me

      # Build if we need to
      if always_build?
        execute_build(@fetcher)
      else
        if Omnibus::InstallPathCache.new(install_dir, self).restore
          true
        else
          execute_build(@fetcher)
        end
      end

      project.build_version_dsl.resolve(self)
      true
    end

    # Fetch the software
    def fetch_me
      # Create the directories we need
      [build_dir, Config.source_dir, Config.cache_dir, project_dir].each do |dir|
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

    # A PATH variable format string representing the current PATH with the
    # project's embedded/bin directory prepended. The correct path separator
    # for the platform is used to join the paths.
    #
    # @params env [Hash]
    # @return [Hash]
    def with_embedded_path(env = {})
      path_value = prepend_path("#{install_dir}/bin", "#{install_dir}/embedded/bin")
      env.merge(path_key => path_value)
    end

    # A PATH variable format string representing the current PATH with the
    # given path prepended. The correct path separator
    # for the platform is used to join the paths.
    #
    # @param paths [String]
    # @param paths [Array<String>]
    # @return [String]
    def prepend_path(*paths)
      path_values = Array(paths)
      path_values << ENV[path_key]

      separator = File::PATH_SEPARATOR || ':'
      path_values.join(separator)
    end

    # Add standard compiler flags to the environment hash to produce omnibus
    # binaries (correct RPATH, etc).
    #
    # Supported options:
    #    :aix => :use_gcc    force using gcc/g++ compilers on aix
    #
    # @params env [Hash]
    # @params opt [Hash]
    # @return [Hash]
    def with_standard_compiler_flags(env = {}, opts = {})
      env ||= {}
      opts ||= {}
      compiler_flags =
        case platform
        when "aix"
          cc_flags =
            if opts[:aix] && opts[:aix][:use_gcc]
              {
                "CC" => "gcc -maix64",
                "CXX" => "g++ -maix64",
                "CFLAGS" => "-maix64 -O -I#{install_dir}/embedded/include",
                "LDFLAGS" => "-L#{install_dir}/embedded/lib -Wl,-blibpath:#{install_dir}/embedded/lib:/usr/lib:/lib",
              }
            else
              {
                "CC" => "xlc -q64",
                "CXX" => "xlC -q64",
                "CFLAGS" => "-q64 -I#{install_dir}/embedded/include -O",
                "LDFLAGS" => "-q64 -L#{install_dir}/embedded/lib -Wl,-blibpath:#{install_dir}/embedded/lib:/usr/lib:/lib",
              }
            end
          cc_flags.merge({
            "LD" => "ld -b64",
            "OBJECT_MODE" => "64",
            "ARFLAGS" => "-X64 cru",
          })
        when "mac_os_x"
          {
            "LDFLAGS" => "-L#{install_dir}/embedded/lib",
            "CFLAGS" => "-I#{install_dir}/embedded/include",
          }
        when "solaris2"
          {
            "LDFLAGS" => "-R#{install_dir}/embedded/lib -L#{install_dir}/embedded/lib -static-libgcc",
            "CFLAGS" => "-I#{install_dir}/embedded/include",
          }
        else
          {
            "LDFLAGS" => "-Wl,-rpath,#{install_dir}/embedded/lib -L#{install_dir}/embedded/lib",
            "CFLAGS" => "-I#{install_dir}/embedded/include",
          }
        end

      # merge LD_RUN_PATH into the environment.  most unix distros will fall
      # back to this if there is no LDFLAGS passed to the linker that sets
      # the rpath.  the LDFLAGS -R or -Wl,-rpath will override this, but in
      # some cases software may drop our LDFLAGS or think it knows better
      # and edit them, and we *really* want the rpath setting and do know
      # better.  in that case LD_RUN_PATH will probably survive whatever
      # edits the configure script does
      extra_linker_flags = {
        "LD_RUN_PATH" => "#{install_dir}/embedded/lib"
      }
      # solaris linker can also use LD_OPTIONS, so we throw the kitchen sink against
      # the linker, to find every way to make it use our rpath.
      extra_linker_flags.merge!(
        {
          "LD_OPTIONS" => "-R#{install_dir}/embedded/lib"
        }
      ) if platform == "solaris2"
      env.merge(compiler_flags).
        merge(extra_linker_flags).
        # always want to favor pkg-config from embedded location to not hose
        # configure scripts which try to be too clever and ignore our explicit
        # CFLAGS and LDFLAGS in favor of pkg-config info
        merge({"PKG_CONFIG_PATH" => "#{install_dir}/embedded/lib/pkgconfig"})
    end

    private

    def path_key
      # The ruby devkit needs ENV['Path'] set instead of ENV['PATH'] because
      # $WINDOWSRAGE, and if you don't set that your native gem compiles
      # will fail because the magic fixup it does to add the mingw compiler
      # stuff won't work.
      platform == "windows" ? "Path" : "PATH"
    end

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

    # @todo Remove this in the next major release
    def command(*)
      log.deprecated(log_key) do
        'Software#command. Please use something else.'
      end

      raise 'Method Moved.'
    end

    def execute_build(fetcher)
      fetcher.clean
      @builder.build
      log.info(log_key) { 'Caching build' }
      Omnibus::InstallPathCache.new(install_dir, self).incremental
      log.info(log_key) { 'Dirtied the cache!' }
      project.dirty!
    end

    def touch(file)
      File.open(file, 'w') do |f|
        f.print ''
      end
    end

    def log_key
      @log_key ||= "#{super}: #{name}"
    end
  end
end
