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

require 'fileutils'
require 'mixlib/shellout'
require 'ostruct'
require 'pathname'

module Omnibus
  class Builder
    # Files to be ignored during a directory globbing
    IGNORED_FILES = %w(. ..).freeze

    include Cleanroom
    include Digestable
    include Instrumentation
    include Logging
    include Util

    #
    # Since builder is also a proxy object to software, we dynamically re-define
    # all the methods that exist on {Software} as proxy methhods here. This
    # permits developers to use {Software} methods as if they were directly
    # part of this DSL.
    #
    Software.exposed_methods.each do |name, _|
      define_method(name) do |*args, &block|
        software.send(name, *args, &block)
      end
      expose(name)
    end

    #
    # @return [Software]
    #   the software definition that created this builder
    #
    attr_reader :software

    #
    # Create a new builder object for evaluation.
    #
    # @param [Software] software
    #   the software definition that created this builder
    #
    def initialize(software)
      @software = software
    end

    #
    # @!group System DSL methods
    #
    # The following DSL methods are available from within build blocks.
    # --------------------------------------------------

    #
    # Execute the given command string or command arguments.
    #
    # @example
    #   command 'make install', env: { 'PATH' => '/my/custom/path' }
    #
    # @param [String] command
    #   the command to execute
    # @param [Hash] options
    #   a list of options to pass to the +Mixlib::ShellOut+ instance when it is
    #   executed
    #
    # @return [void]
    #
    def command(command, options = {})
      build_commands << BuildCommand.new("Execute: `#{command}'") do
        _shellout!(command, options)
      end
    end
    expose :command

    #
    # Apply the patch by the given name. This method will search all possible
    # locations for a patch (such as {Config#software_gems}).
    #
    # @example
    #   patch source: 'ncurses-clang.patch'
    #
    # @example
    #   patch source: 'patch-ad', plevel: 0
    #
    # @param [Hash] options
    #   the list of options
    #
    # @option options [String] :source
    #   the name of the patch to apply
    # @option options [Fixnum] :plevel
    #   the level to apply the patch
    # @option options [String] :target
    #   the destination to apply the patch
    #
    # @return (see #command)
    #
    def patch(options = {})
      source = options.delete(:source)
      plevel = options.delete(:plevel) || 1
      target = options.delete(:target)

      locations, patch_path = find_file('config/patches', source)

      unless patch_path
        raise MissingPatch.new(source, locations)
      end

      # Apply patches nicely on Windows
      patch_path = windows_safe_path(patch_path)

      if target
        command = "cat #{patch_path} | patch -p#{plevel} #{target}"
      else
        command = "patch -d #{software.project_dir} -p#{plevel} -i #{patch_path}"
      end

      patches << patch_path

      build_commands << BuildCommand.new("Apply patch `#{source}'") do
        _shellout!(command, options)
      end
    end
    expose :patch

    #
    # The maximum number of build jobs, as computed from Ohai data. If the Ohai
    # data is unavailable, +3+ is used.
    #
    # @todo Should this be moved to {Software}?
    #
    # @example
    #   command "make install -j#{max_build_jobs}"
    #
    # @return [Fixnum]
    #
    def max_build_jobs
      if Ohai['cpu'] && Ohai['cpu']['total'] && Ohai['cpu']['total'].to_s =~ /^\d+$/
        Ohai['cpu']['total'].to_i + 1
      else
        3
      end
    end
    expose :max_build_jobs

    #
    # Convert the given path to be appropiate for shelling out on Windows. Most
    # internal calls will wrap paths automatically, but the +command+ method is
    # unable to do so.
    #
    # @example
    #   command "#{windows_safe_path(install_dir)}\\embedded\\bin\\gem"
    #
    # @param [String, Array<String>] pieces
    #   the pieces of the path to join and fix
    # @return [String]
    #   the path with applied changes
    #
    def windows_safe_path(*pieces)
      path = File.join(*pieces)

      if File::ALT_SEPARATOR
        path.gsub(File::SEPARATOR, File::ALT_SEPARATOR)
      else
        path
      end
    end
    expose :windows_safe_path

    #
    # @!endgroup
    # --------------------------------------------------

    #
    # @!group Ruby DSL methods
    #
    # The following DSL methods are available from within build blocks and
    # expose Ruby DSL methods.
    # --------------------------------------------------

    #
    # Execute the given Ruby command or script against the embedded Ruby.
    #
    # @example
    #   ruby 'setup.rb'
    #
    # @param (see #command)
    # @return (see #command)
    #
    def ruby(command, options = {})
      build_commands << BuildCommand.new("ruby `#{command}'") do
        bin = windows_safe_path("#{install_dir}/embedded/bin/ruby")
        _shellout!("#{bin} #{command}", options)
      end
    end
    expose :ruby

    #
    # Execute the given Rubygem command against the embedded Rubygems.
    #
    # @example
    #   gem 'install chef'
    #
    # @param (see #command)
    # @return (see #command)
    #
    def gem(command, options = {})
      build_commands << BuildCommand.new("gem `#{command}'") do
        bin = windows_safe_path("#{install_dir}/embedded/bin/gem")
        _shellout!("#{bin} #{command}", options)
      end
    end
    expose :gem

    #
    # Execute the given bundle command against the embedded Ruby's bundler. This
    # command assumes the +bundler+ gem is installed and in the embedded Ruby.
    # You should add a dependency on the +bundler+ software definition if you
    # want to use this command.
    #
    # @example
    #   bundle 'install'
    #
    # @param (see #command)
    # @return (see #command)
    #
    def bundle(command, options = {})
      build_commands << BuildCommand.new("bundle `#{command}'") do
        bin = windows_safe_path("#{install_dir}/embedded/bin/bundle")
        _shellout!("#{bin} #{command}", options)
      end
    end
    expose :bundle

    #
    # Execute the given Rake command against the embedded Ruby's rake. This
    # command assumes the +rake+ gem has been installed.
    #
    # @example
    #   rake 'test'
    #
    # @param (see #command)
    # @return (see #command)
    #
    def rake(command, options = {})
      build_commands << BuildCommand.new("rake `#{command}'") do
        bin = windows_safe_path("#{install_dir}/embedded/bin/rake")
        _shellout!("#{bin} #{command}", options)
      end
    end
    expose :rake

    #
    # Execute the given Ruby block at runtime. The block is captured as-is and
    # no validation is performed. As a general rule, you should avoid this
    # method unless you know what you are doing.
    #
    # TODO: the "name" does nothing right now
    #
    # @example
    #   block do
    #     # Some complex operation
    #   end
    #
    # @example
    #   block 'Named operation' do
    #     # The above name can be used in log output to identify the operation
    #   end
    #
    # @param (see #command)
    # @return (see #command)
    #
    def block(name = '<Dynamic Ruby block>', &proc)
      build_commands << BuildCommand.new(name, &proc)
    end
    expose :block

    #
    # Render the erb template by the given name. This method will search all
    # possible locations for an erb template (such as {Config#software_gems}).
    #
    # @example
    #   erb source: 'example.erb',
    #       dest:   '/path/on/disk/to/render'
    #
    # @example
    #   erb source: 'example.erb',
    #       dest:   '/path/on/disk/to/render',
    #       vars:   { foo: 'bar' },
    #       mode:   '0755'
    #
    # @param [Hash] options
    #   the list of options
    #
    # @option options [String] :source
    #   the name of the patch to apply
    # @option options [String] :dest
    #   the path on disk where the erb should be rendered
    # @option options [Hash] :vars
    #   the list of variables to pass to the ERB rendering
    # @option options [String] :mode
    #   the file mode for the rendered template (default varies by system)
    #
    # @return (see #command)
    #
    def erb(options = {})
      source = options.delete(:source)
      dest   = options.delete(:dest)
      mode   = options.delete(:mode) || 0644
      vars   = options.delete(:vars) || {}

      raise "Missing required option `:source'!" unless source
      raise "Missing required option `:dest'!"   unless dest

      locations, source_path = find_file('config/templates', source)

      unless source_path
        raise MissingTemplate.new(source, locations)
      end

      erbs << source_path

      block "Render erb `#{source}'" do
        template = ERB.new(File.read(source_path), nil, '%')
        struct   = OpenStruct.new(vars)
        result   = template.result(struct.instance_eval { binding })

        File.open(dest, 'w') do |file|
          file.write(result)
        end

        File.chmod(mode, dest)
      end
    end
    expose :erb

    #
    # @!endgroup
    # --------------------------------------------------

    #
    # @!group File system DSL methods
    #
    # The following DSL methods are available from within build blocks that
    # mutate the file system.
    #
    # **These commands are run from inside {Software#install_dir}, so exercise
    # good judgement when using relative paths!**
    # --------------------------------------------------

    #
    # Make a directory at runtime. This method uses the equivalent of +mkdir -p+
    # under the covers.
    #
    # @param [String] directory
    #   the name or path of the directory to create
    # @param [Hash] options
    #   the list of options to pass to the underlying +FileUtils+ call
    #
    # @return (see #command)
    #
    def mkdir(directory, options = {})
      build_commands << BuildCommand.new("mkdir `#{directory}'") do
        Dir.chdir(software.install_dir) do
          FileUtils.mkdir_p(directory, options)
        end
      end
    end
    expose :mkdir

    #
    # Touch the given filepath at runtime. This method will also ensure the
    # containing directory exists first.
    #
    # @param [String] file
    #   the path of the file to touch
    # @param (see #mkdir)
    #
    # @return (see #command)
    #
    def touch(file, options = {})
      build_commands << BuildCommand.new("touch `#{file}'") do
        Dir.chdir(software.install_dir) do
          parent = File.dirname(file)
          FileUtils.mkdir_p(parent) unless File.directory?(parent)

          FileUtils.touch(file, options)
        end
      end
    end
    expose :touch

    #
    # Delete the given file or directory on the system. This method uses the
    # equivalent of +rm -rf+, so you may pass in a specific file or a glob of
    # files.
    #
    # @param [String] path
    #   the path of the file to delete
    # @param (see #mkdir)
    #
    # @return (see #command)
    #
    def delete(path, options = {})
      build_commands << BuildCommand.new("delete `#{path}'") do
        Dir.chdir(software.install_dir) do
          glob(path).each do |file|
            FileUtils.rm_rf(file, options)
          end
        end
      end
    end
    expose :delete

    #
    # Copy the given source to the destination. This method accepts a single
    # file or a file pattern to match.
    #
    # @param [String] source
    #   the path on disk to copy from
    # @param [String] destination
    #   the path on disk to copy to
    # @param (see #mkdir)
    #
    # @return (see #command)
    #
    def copy(source, destination, options = {})
      build_commands << BuildCommand.new("copy `#{source}' to `#{destination}'") do
        Dir.chdir(software.install_dir) do
          glob(source).each do |file|
            FileUtils.cp_r(file, destination, options)
          end
        end
      end
    end
    expose :copy

    #
    # Copy the given source to the destination. This method accepts a single
    # file or a file pattern to match
    #
    # @param [String] source
    #   the path on disk to move from
    # @param [String] destination
    #   the path on disk to move to
    # @param (see #mkdir)
    #
    # @return (see #command)
    #
    def move(source, destination, options = {})
      build_commands << BuildCommand.new("move `#{source}' to `#{destination}'") do
        Dir.chdir(software.install_dir) do
          glob(source).each do |file|
            FileUtils.mv(file, destination, options)
          end
        end
      end
    end
    expose :move

    #
    # Link the given source to the destination. This method accepts a single
    # file or a file pattern to match
    #
    # @param [String] source
    #   the path on disk to link from
    # @param [String] destination
    #   the path on disk to link to
    # @param (see #mkdir)
    #
    # @return (see #command)
    #
    def link(source, destination, options = {})
      build_commands << BuildCommand.new("link `#{source}' to `#{destination}'") do
        Dir.chdir(software.install_dir) do
          glob(source).each do |file|
            FileUtils.ln_s(file, destination, options)
          end
        end
      end
    end
    expose :link

    #
    # Copy the files from +source+ to +destination+, while removing any files
    # in +destination+ that are not present in +source+.
    #
    # You can pass the option +:exclude+ option to ignore files and folders that
    # match the given pattern(s). Note the exclude pattern behaves on paths
    # relative to the given source. If you want to exclude a nested directory,
    # you will need to use something like +**/directory+.
    #
    # @example
    #   sync "#{project_dir}/**/*.rb", "#{install_dir}/ruby_files"
    #
    # @example
    #   sync project_dir, "#{install_dir}/files", exclude: '.git'
    #
    # @param [String] source
    #   the path on disk to sync from
    # @param [String] destination
    #   the path on disk to sync to
    #
    # @option options [String, Array<String>] :exclude
    #   a file, folder, or globbing pattern of files to ignore when syncing
    #
    # @return (see #command)
    #
    def sync(source, destination, options = {})
      build_commands << BuildCommand.new("sync `#{source}' to `#{destination}'") do
        Dir.chdir(software.install_dir) do
          # The source must be a destination in the sync command
          unless File.directory?(source)
            raise ArgumentError, "`source' must be a directory, but was a " \
              "`#{File.ftype(source)}'! If you just want to sync a file, use " \
              "the `copy' method instead."
          end

          # Reject any files that match the excludes pattern
          excludes = Array(options[:exclude]).map do |exclude|
            [exclude, "#{exclude}/*"]
          end.flatten

          source_files = all_files(source)
          source_files = source_files.reject do |source_file|
            basename = relative_path_for(source_file, source)
            excludes.any? { |exclude| File.fnmatch?(exclude, basename, File::FNM_DOTMATCH) }
          end

          # Ensure the destination directory exists
          FileUtils.mkdir_p(destination) unless File.directory?(destination)

          # Copy over the filtered source files
          FileUtils.cp_r(source_files, destination)

          # Remove any files in the destination that are not in the source files
          destination_files = all_files(destination)

          # Calculate the relative paths of files so we can compare to the
          # source.
          relative_source_files = source_files.map do |file|
            relative_path_for(file, source)
          end
          relative_destination_files = destination_files.map do |file|
            relative_path_for(file, destination)
          end

          # Remove any extra files that are present in the destination, but are
          # not in the source list
          extra_files = relative_destination_files - relative_source_files
          extra_files.each do |file|
            FileUtils.rm_rf(File.join(destination, file))
          end
        end
      end
    end

    #
    # @!endgroup
    # --------------------------------------------------

    #
    # @!group Public API
    #
    # The following methods are considered part of the public API for a
    # builder. All DSL methods are also considered part of the public API.
    # --------------------------------------------------

    #
    # Execute all the {BuildCommand} instances, in order, for this builder.
    #
    # @return [void]
    #
    def build
      log.info(log_key) { 'Starting build' }

      if software.overridden?
        log.info(log_key) do
          "Version overridden from #{software.default_version} to "\
          "#{software.version}"
        end
      end

      measure("Build #{software.name}") do
        build_commands.each do |command|
          execute(command)
        end
      end

      log.info(log_key) { 'Finished build' }
    end

    #
    # The shasum for this builder object. The shasum is calculated using the
    # following:
    #
    #   - The descriptions of all {BuildCommand} objects
    #   - The digest of all patch files on disk
    #   - The digest of all erb files on disk
    #
    # @return [String]
    #
    def shasum
      @shasum ||= begin
        digest = Digest::SHA256.new

        build_commands.each do |build_command|
          update_with_string(digest, build_command.description)
        end

        patches.each do |patch_path|
          update_with_file_contents(digest, patch_path)
        end

        erbs.each do |erb_path|
          update_with_file_contents(digest, erb_path)
        end

        digest.hexdigest
      end
    end

    #
    # @!endgroup
    # --------------------------------------------------

    private

    #
    # The **in-order** list of {BuildCommand} for this builder.
    #
    # @return [Array<BuildCommand>]
    #
    def build_commands
      @build_commands ||= []
    end

    #
    # The list of paths to patch files on disk. This is used in the calculation
    # of the shasum.
    #
    # @return [Array<String>]
    #
    def patches
      @patches ||= []
    end

    #
    # The list of paths to erb files on disk. This is used in the calculation
    # of the shasum.
    #
    # @return [Array<String>]
    #
    def erbs
      @erbs ||= []
    end

    #
    # This is a helper method that wraps {Util#shellout!} for the purposes of
    # setting the +:cwd+ value.
    #
    # @see (Util#shellout!)
    #
    def _shellout!(command_string, options = {})
      # Make sure the PWD is set to the correct directory
      options = { cwd: software.project_dir }.merge(options)

      # Use Util's shellout
      shellout!(command_string, options)
    end

    #
    # Execute the given command object. This method also wraps the following
    # operations:
    #
    #   - Reset bundler's environment using {with_clean_env}
    #   - Instrument (time/measure) the individual command's execution
    #   - Retry failed commands in accordance with {Config#build_retries}
    #
    # @param [BuildCommand] command
    #   the command object to build
    #
    def execute(command)
      with_clean_env do
        measure(command.description) do
          with_retries do
            command.run(self)
          end
        end
      end
    end

    #
    # Execute the given block with (n) reties defined by {Config#build_retries}.
    # This method will only retry for the following exceptions:
    #
    #   - +Mixlib::ShellOut::ShellCommandFailed+
    #   - +Mixlib::ShellOut::CommandTimeout+
    #
    # @param [Proc] block
    #   the block to execute
    #
    def with_retries(&block)
      tries = Config.build_retries
      delay = 5
      exceptions = [
        Mixlib::ShellOut::ShellCommandFailed,
        Mixlib::ShellOut::CommandTimeout,
      ]

      begin
        block.call
      rescue *exceptions => e
        if tries <= 0
          raise e
        else
          delay = delay * 2

          log.warn(log_key) do
            label = "#{(Config.build_retries - tries) + 1}/#{Config.build_retries}"
            "[#{label}] Failed to execute command. Retrying in #{delay} seconds..."
          end

          sleep(delay)
          tries -= 1
          retry
        end
      end
    end

    #
    # Execute the given command, removing any Ruby-specific environment
    # variables. This is an "enhanced" version of +Bundler.with_clean_env+,
    # which only removes Bundler-specific values. We need to remove all
    # values, specifically:
    #
    # - GEM_PATH
    # - GEM_HOME
    # - GEM_ROOT
    # - BUNDLE_GEMFILE
    # - RUBYOPT
    #
    # The original environment restored at the end of this call.
    #
    # @param [Proc] block
    #   the block to execute with the cleaned environment
    #
    def with_clean_env(&block)
      original = ENV.to_hash

      ENV.delete('RUBYOPT')
      ENV.delete_if { |k,_| k.start_with?('BUNDLE_') }
      ENV.delete_if { |k,_| k.start_with?('GEM_') }

      block.call
    ensure
      ENV.replace(original.to_hash)
    end

    #
    # Find a file amonst all local files, "remote" local files, and
    # {Config#software_gems}.
    #
    # @param [String] path
    #   the path to find the file
    # @param [String] source
    #   the source name of the file to find
    #
    # @return [Array<Array<String>, String, nil>]
    #   an array where the first entry is the list of candidate paths searched,
    #   and the second entry is the first occurence of the matched file (or
    #   +nil+) if one does not exist.
    #
    def find_file(path, source)
      # Search for patches just like we search for software
      candidate_paths = Omnibus.software_dirs.map do |directory|
        full_path = directory.sub(Config.software_dir, path)
        "#{full_path}/#{software.name}/#{source}"
      end

      file = candidate_paths.find { |path| File.exist?(path) }

      [candidate_paths, file]
    end

    #
    # Get all the regular files and directories at the given path. It is assumed
    # this path is a fully-qualified path and/or executed from a proper relative
    # path.
    #
    # @param [String] path
    #   the path to get all files from
    #
    # @return [Array<String>]
    #   the list of all files
    #
    def all_files(path)
      Dir.glob("#{path}/**/*", File::FNM_DOTMATCH).reject do |file|
        basename = File.basename(file)
        IGNORED_FILES.include?(basename)
      end
    end

    #
    # The relative path of the given +path+ to the +parent+.
    #
    # @param [String] path
    #   the path to get relative with
    # @param [String] parent
    #   the parent where the path is contained (hopefully)
    #
    # @return [String]
    #
    def relative_path_for(path, parent)
      Pathname.new(path).relative_path_from(Pathname.new(parent)).to_s
    end

    #
    # The log key for this class, overriden to incorporate the software name.
    #
    # @return [String]
    #
    def log_key
      @log_key ||= "#{super}: #{software.name}"
    end

    #
    # Glob across the given pattern, accounting for dotfiles, removing Ruby's
    # dumb idea to include +'.'+ and +'..'+ as entries.
    #
    # @param [String] path
    #   the path to get all files from
    #
    # @return [Array<String>]
    #   the list of all files
    #
    def glob(pattern)
      Dir.glob(pattern, File::FNM_DOTMATCH).reject do |file|
        basename = File.basename(file)
        IGNORED_FILES.include?(basename)
      end
    end

    #
    # This is an internal wrapper around a command executed on the system. The
    # block could contain a Ruby command (such as +FileUtils.rm_rf('/')+), or it
    # could contain a call to shell out to the system.
    #
    class BuildCommand
      attr_reader :description

      #
      # Create a new BuildCommand object.
      #
      # @param [String] description
      #   a unique identifier for this build command - it will be used for
      #   logging and timing labels
      # @param [Proc] block
      #   the block to capture
      #
      def initialize(description, &block)
        @description, @block = description, block
      end

      #
      # Execute the build command against the given object. Because BuildCommand
      # objects could reference internal DSL methods, this method requires you
      # pass in an object against which to +instance_eval+ the block. Otherwise,
      # you would be severly restricted in the commands avaiable to you via the
      # DSL.
      #
      # @param [Builder] builder
      #   the builder to +instance_eval+ against
      #
      def run(builder)
        builder.instance_eval(&@block)
      end
    end
  end
end
