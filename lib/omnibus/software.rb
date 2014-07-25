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
      # @param [String] name
      #   the path to the software definition to load from disk
      #
      # @return [Software]
      #
      def load(project, name)
        loaded_softwares[name] ||= begin
          filepath = Omnibus.software_path(name)

          if filepath.nil?
            raise MissingSoftware.new(name)
          else
            log.debug(log_key) do
              "Loading software `#{name}' from `#{filepath}'."
            end
          end

          instance = new(project, filepath)
          instance.evaluate_file(filepath)
          instance.load_dependencies
          instance
        end
      end

      private

      #
      # The list of softwares loaded thus far.
      #
      # @return [Hash<String, Software>]
      #
      def loaded_softwares
        @loaded_softwares ||= {}
      end
    end

    include Cleanroom
    include Digestable
    include Logging
    include NullArgumentable
    include Sugarable

    #
    # Create a new software object.
    #
    # @param [Project] project
    #   the Omnibus project that instantiated this software definition
    # @param [String] filepath
    #   the path to where this software definition lives on disk
    #
    # @return [Software]
    #
    def initialize(project, filepath = nil)
      unless project.is_a?(Project)
        raise ArgumentError,
          "`project' must be a kind of `Omnibus::Project', but was `#{project.class.inspect}'!"
      end

      # Magical methods
      @filepath = filepath
      @project  = project

      # Overrides
      @overrides = NULL
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
    # @option val [String] :cookie (nil)
    #   a cookie to set
    # @option val [String] :warning (nil)
    #   a warning message to print when downloading
    #
    # @return [Hash]
    #
    def source(val = NULL)
      unless null?(val)
        unless val.is_a?(Hash)
          raise InvalidValue.new(:source,
            "be a kind of `Hash', but was `#{val.class.inspect}'")
        end

        extra_keys = val.keys - [:git, :path, :url, :md5, :cookie, :warning]
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
      File.expand_path("#{Config.source_dir}/#{relative_path}")
    end
    expose :project_dir

    #
    # The path where the software will be built.
    #
    # @return [String]
    #
    def build_dir
      File.expand_path("#{Config.build_dir}/#{project.name}")
    end
    expose :build_dir

    #
    # The directory where this software is installed on disk.
    #
    # @example
    #   { 'PATH' => "#{install_dir}/embedded/bin:#{ENV["PATH"]}", }
    #
    # @return [String]
    #
    def install_dir
      @project.install_dir
    end
    expose :install_dir

    #
    # Define a series of {Builder} DSL commands that are executed to build the
    # software.
    #
    # @see Builder
    #
    # @param [Proc] block
    #   a block of build commands
    #
    # @return [Proc]
    #   the build block
    #
    def build(&block)
      builder.evaluate(&block)
    end
    expose :build

    #
    # The path to the downloaded file from a NetFetcher.
    #
    # @deprecated There is no replacement for this DSL method
    #
    def project_file
      if fetcher && fetcher.is_a?(NetFetcher)
        log.deprecated(log_key) do
          "project_file (DSL). This is a property of the NetFetcher and will " \
          "not be publically exposed in the next major release. In general, " \
          "you should not be using this method in your software definitions " \
          "as it is an internal implementation detail of the NetFetcher. If " \
          "you disagree with this statement, you should open an issue on the " \
          "Omnibus repository on GitHub an explain your use case. For now, " \
          "I will return the path to the downloaded file on disk, but please " \
          "rethink the problem you are trying to solve :)."
        end

        fetcher.downloaded_file
      else
        log.warn(log_key) do
          "Cannot retrieve a `project_file' for software `#{name}'. This " \
          "attribute is actually an internal representation that is unique " \
          "to the NetFetcher class and requires the use of a `source' " \
          "attribute that is declared using a `:url' key. For backwards-" \
          "compatability, I will return `nil', but this is most likely not " \
          "your desired behavior."
        end

        nil
      end
    end
    expose :project_file

    #
    # Add standard compiler flags to the environment hash to produce omnibus
    # binaries (correct RPATH, etc).
    #
    # Supported options:
    #    :aix => :use_gcc    force using gcc/g++ compilers on aix
    #
    # @params [Hash] env
    # @params [Hash] opts
    #
    # @return [Hash]
    #
    def with_standard_compiler_flags(env = {}, opts = {})
      env ||= {}
      opts ||= {}
      compiler_flags =
        case Ohai['platform']
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
        when "freebsd"
          {
            "LDFLAGS" => "-R#{install_dir}/embedded/lib -L#{install_dir}/embedded/lib",
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
      ) if Ohai['platform'] == "solaris2"
      env.merge(compiler_flags).
        merge(extra_linker_flags).
        # always want to favor pkg-config from embedded location to not hose
        # configure scripts which try to be too clever and ignore our explicit
        # CFLAGS and LDFLAGS in favor of pkg-config info
        merge({"PKG_CONFIG_PATH" => "#{install_dir}/embedded/lib/pkgconfig"})
    end
    expose :with_standard_compiler_flags

    #
    # A PATH variable format string representing the current PATH with the
    # project's embedded/bin directory prepended. The correct path separator
    # for the platform is used to join the paths.
    #
    # @params [Hash] env
    #
    # @return [Hash]
    #
    def with_embedded_path(env = {})
      path_value = prepend_path("#{install_dir}/bin", "#{install_dir}/embedded/bin")
      env.merge(path_key => path_value)
    end
    expose :with_embedded_path

    #
    # A PATH variable format string representing the current PATH with the
    # given path prepended. The correct path separator
    # for the platform is used to join the paths.
    #
    # @param [Array<String>] paths
    #
    # @return [String]
    #
    def prepend_path(*paths)
      path_values = Array(paths)
      path_values << ENV[path_key]

      separator = File::PATH_SEPARATOR || ':'
      path_values.join(separator)
    end
    expose :prepend_path

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
    # Recursively load all the dependencies for this software.
    #
    # @return [true]
    #
    def load_dependencies
      dependencies.each do |dependency|
        software = Software.load(project, dependency)
        project.library.component_added(software)
      end

      true
    end

    #
    # The builder object for this software definition.
    #
    # @return [Builder]
    #
    def builder
      @builder ||= Builder.new(self)
    end

    #
    # Fetch the software definition using the appropriate fetcher. This may
    # fetch the software from a local path location, git location, or download
    # the software from a remote URL (HTTP(s)/FTP)
    #
    # @return [true, false]
    #   true if the software was fetched, false if it was cached
    #
    def fetch
      if fetcher.fetch_required?
        fetcher.fetch
        true
      else
        false
      end
    end

    #
    # The list of software dependencies for this software. These is the software
    # that comprises your software, and is distinct from runtime dependencies.
    #
    # @see #dependency
    #
    # @param [Array<String>]
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

    # @todo see comments on {Omnibus::Fetcher#without_caching_for}
    def version_guid
      fetcher.version_guid
    end

    # Returns the version to be used in cache.
    def version_for_cache
      @version_for_cache ||= if fetcher.version_for_cache
        fetcher.version_for_cache
      elsif version
        version
      else
        log.warn(log_key) do
          "No version given! This is probably a bad thing. I am going to " \
          "assume the version `0.0.0', but that is most certainly not your " \
          "desired behavior. If git caching seems off, this is probably why."
        end

        '0.0.0'
      end
    end

    #
    # The fetcher for this software, based off of the +source+ attribute.
    #
    # - +:url+ - {NetFetcher}
    # - +:git+ - {GitFetcher}
    # - +:path+ - {PathFetcher}
    #
    # @return [Fetcher]
    #
    def fetcher
      @fetcher ||= if source
        if source[:url]
          NetFetcher.new(self)
        elsif source[:git]
          GitFetcher.new(self)
        elsif source[:path]
          PathFetcher.new(self)
        end
      else
        NullFetcher.new(self)
      end
    end

    # Actually build the software package
    def build_me
      # Build if we need to
      if always_build?
        execute_build
      else
        if GitCache.new(self).restore
          true
        else
          execute_build
        end
      end

      project.build_version_dsl.resolve(self)
      true
    end

    #
    # The unique "hash" for this software.
    #
    # @see (#shasum)
    #
    # @return [Fixnum]
    #
    def hash
      shasum.hash
    end

    #
    # Determine if two softwares are identical.
    #
    # @param [Software] other
    #
    # @return [true, false]
    #
    def ==(other)
      self.hash == other.hash
    end
    alias_method :eql?, :==

    #
    # The unique SHA256 for this sofware definition.
    #
    # A software is defined by its parent project's shasum, its own name, its
    # version_for_cache, and any overrides (as JSON). Additionally, if provided,
    # the actual file contents are included in the SHA to ensure uniqueness.
    #
    # @return [String]
    #
    def shasum
      @shasum ||= begin
        digest = Digest::SHA256.new

        log.debug(log_key) { "project (SHA): #{project.shasum.inspect}" }
        log.debug(log_key) { "builder (SHA): #{builder.shasum.inspect}" }
        log.debug(log_key) { "name: #{name.inspect}" }
        log.debug(log_key) { "version_for_cache: #{version_for_cache.inspect}" }
        log.debug(log_key) { "overrides: #{overrides.inspect}" }

        update_with_string(digest, project.shasum)
        update_with_string(digest, builder.shasum)
        update_with_string(digest, name)
        update_with_string(digest, version_for_cache)
        update_with_string(digest, JSON.fast_generate(overrides))

        if filepath && File.exist?(filepath)
          log.debug(log_key) { "filepath: #{filepath.inspect}" }
          update_with_file_contents(digest, filepath)
        else
          log.debug(log_key) { "filepath: <DYNAMIC>" }
          update_with_string(digest, '<DYNAMIC>')
        end

        shasum = digest.hexdigest

        log.debug(log_key) { "shasum: #{shasum.inspect}" }

        shasum
      end
    end

    private

    #
    # Determine if this software should always be built. A software should
    # always be built if git caching is disabled ({Config#use_git_caching}) or
    # if the parent project has dirtied the cache.
    #
    # @return [true, false]
    #
    def always_build?
      unless Config.use_git_caching
        return true
      end

      if project.dirty?
        return true
      end

      !!@always_build
    end

    #
    # The proper platform-specific "$PATH" key.
    #
    # @return [String]
    #
    def path_key
      # The ruby devkit needs ENV['Path'] set instead of ENV['PATH'] because
      # $WINDOWSRAGE, and if you don't set that your native gem compiles
      # will fail because the magic fixup it does to add the mingw compiler
      # stuff won't work.
      Ohai['platform'] == 'windows' ? 'Path' : 'PATH'
    end

    #
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

    def execute_build
      fetcher.clean
      builder.build

      if Config.use_git_caching
        log.info(log_key) { 'Caching build' }
        GitCache.new(self).incremental
        log.info(log_key) { 'Dirtied the cache!' }
      end

      project.dirty!
    end

    def log_key
      @log_key ||= "#{super}: #{name}"
    end
  end
end
