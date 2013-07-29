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

require 'rake'

module Omnibus

  # Omnibus software DSL reader
  class Software
    include Rake::DSL

    NULL_ARG = Object.new

    # It appears that this is not used
    attr_reader :builder

    # @todo Why do we apparently use two different ways of
    #   implementing what are effectively the same DSL methods?  Compare
    #   with Omnibus::Project.
    attr_reader :description

    # @todo This doesn't appear to be used at all
    attr_reader :fetcher

    attr_reader :project

    attr_reader :given_version
    attr_reader :override_version
    attr_reader :whitelist_files

    def self.load(filename, project, overrides={})
      new(IO.read(filename), filename, project, overrides)
    end

    # @param io [String]
    # @param filename [String]
    # @param project [???] Is this a string or an Omnibus::Project?
    # @param overrides [Hash]
    #
    # @see Omnibus::Overrides
    #
    # @todo See comment on {Omnibus::NullBuilder}
    # @todo does `filename` need to be absolute, or does it matter?
    # @ @todo Any reason to not have this just take a filename,
    #   project, and override hash directly?  That is, why io AND a
    #   filename, if the filename can always get you the contents you
    #   need anyway?
    def initialize(io, filename, project, overrides={})
      @given_version    = nil
      @override_version = nil
      @name             = nil
      @description      = nil
      @source           = nil
      @relative_path    = nil
      @source_uri       = nil
      @source_config    = filename
      @project          = project
      @always_build     = false

      # Seems like this should just be Builder.new(self) instead
      @builder = NullBuilder.new(self)

      @dependencies = Array.new
      @whitelist_files = Array.new
      instance_eval(io, filename, 0)

      # Set override information after the DSL file has been consumed
      @override_version = overrides[name]

      render_tasks
    end

    def name(val=NULL_ARG)
      @name = val unless val.equal?(NULL_ARG)
      @name
    end

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
    def dependencies(val=NULL_ARG)
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
    #   if more than one pair is given, or if no source value is ever
    #   set.
    def source(val=NULL_ARG)
      @source = val unless val.equal?(NULL_ARG)
      @source
    end

    # Set a version from a software descriptor file, or receive the
    # effective version, taking into account any override information
    # (if set)
    def version(val=NULL_ARG)
      @given_version = val unless val.equal?(NULL_ARG)
      @override_version || @given_version
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
      @override_version && (@override_version != @given_version)
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

    # @todo all the *_file methods should be next to each other for
    #   better logical grouping
    def manifest_file
      manifest_file_from_name(@name)
    end

    # @todo Seems like this should be a private method, since it's
    #   just used internally
    def manifest_file_from_name(software_name)
      "#{build_dir}/#{software_name}.manifest"
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
        path.sub!(":", "")
        parts = path.split("\\") - [""]
        parts.join("_")
      else
        parts = path.split("/") - [""]
        parts.join("_")
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
      OHAI.kernel['machine'] =~ /sun/ ? "sparc" : "intel"
    end

    private

    # @todo What?!
    # @todo It seems that this is not used... remove it
    # @deprecated Use something else (?)
    def command(*args)
      raise "Method Moved."
    end

    def execute_build(fetcher)
      fetcher.clean
      @builder.build
      touch manifest_file
    end

    def render_tasks
      namespace "projects:#{@project.name}" do
      namespace :software do
        fetcher = Fetcher.for(self)

        #
        # set up inter-project dependencies
        #
        (@dependencies - [@name]).uniq.each do |dep|
          task @name => dep
          file manifest_file => manifest_file_from_name(dep)
        end

        directory source_dir
        directory cache_dir
        directory build_dir
        directory project_dir
        namespace @name do
          task :fetch => [ build_dir, source_dir, cache_dir, project_dir ] do
            if !File.exists?(fetch_file) || fetcher.fetch_required?
              # force build to run if we need to do an updated fetch
              fetcher.fetch
              touch fetch_file
            end
          end

          task :build => :fetch do
            if !always_build? && uptodate?(manifest_file, [fetch_file])
              # if any direct deps have been built for any reason, we will need to
              # clean/build ourselves
              (@dependencies - [@name]).uniq.each do |dep|
                unless uptodate?(manifest_file, [manifest_file_from_name(dep)])
                  execute_build(fetcher)
                  break
                end
              end

            else
              # if fetch has occurred, or the component is configured to
              # always build, do a clean and build.
              execute_build(fetcher)
            end
          end
        end

        #
        # make the manifest file dependent on the latest file in the
        # source tree in order to shrink the multi-thousand-node
        # dependency graph that Rake was generating
        #
        latest_file = FileList["#{project_dir}/**/*"].sort { |a,b|
          File.mtime(a) <=> File.mtime(b)
        }.last

        file manifest_file => (file latest_file)

        file fetch_file => "#{name}:fetch"
        file manifest_file => "#{name}:build"

        file fetch_file => (file @source_config)
        file manifest_file => (file fetch_file)

        desc "fetch and build #{@name} for #{@project.name}"
        task @name => manifest_file
      end
      end
    end

  end
end
