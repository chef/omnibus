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
    include Cleanroom
    include Digestable
    include Instrumentation
    include Logging
    include Templating
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
      warn_for_shell_commands(command)

      build_commands << BuildCommand.new("Execute: `#{command}'") do
        shellout!(command, options)
      end
    end
    expose :command

    #
    # Execute the given make command. When present, this method will prefer the
    # use of +gmake+ over +make+. If applicable, this method will also set
    # the `MAKE=gmake` environment variable when gmake is to be preferred.
    #
    # @example With no arguments
    #   make
    #
    # @example With arguments
    #   make 'install'
    #
    # @example With custom make bin
    #   make 'install', bin: '/path/to/custom/make'
    #
    # @param (see #command)
    # @return (see #command)
    #
    def make(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      command = args.join(' ')

      make = if makebin = options.delete(:bin)
               makebin
             elsif Omnibus.which('gmake')
               env = options.delete(:env) || {}
               env = { 'MAKE' => 'gmake' }.merge(env)
               options[:env] = env
               'gmake'
             else
               'make'
             end

      command("#{make} #{command}".strip, options)
    end
    expose :make

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
        shellout!(command, options)
      end
    end
    expose :patch

    #
    # The maximum number of workers suitable for this system.
    #
    # @see (Config#workers)
    #
    def workers
      Config.workers
    end
    expose :workers

    #
    # (see Util#windows_safe_path)
    #
    # Most internal Ruby methods will handle this automatically, but the
    # +command+ method is unable to do so.
    #
    # @example
    #   command "#{windows_safe_path(install_dir)}\\embedded\\bin\\gem"
    #
    def windows_safe_path(*pieces)
      super
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
        shellout!("#{bin} #{command}", options)
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
        shellout!("#{bin} #{command}", options)
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
        shellout!("#{bin} #{command}", options)
      end
    end
    expose :bundle

    #
    # Execute the given appbundler command against the embedded Ruby's
    # appbundler. This command assumes the +appbundle+ gem is installed and
    # in the embedded Ruby. You should add a dependency on the +appbundler+
    # software definition if you want to use this command.
    #
    # @example
    #   appbundle 'chef'
    #
    # @param (see #command)
    # @return (see #command)
    #
    def appbundle(app_name, options = {})
      build_commands << BuildCommand.new("appbundle `#{app_name}'") do
        bin_dir            = "#{install_dir}/bin"
        embedded_apps_root = "#{install_dir}/embedded/apps"
        embedded_app_dir   = "#{embedded_apps_root}/#{app_name}"
        gemfile_lock       = "#{embedded_app_dir}/Gemfile.lock"
        appbundler_bin     = windows_safe_path("#{install_dir}/embedded/bin/appbundler")

        # Ensure the main bin dir exists
        FileUtils.mkdir_p(bin_dir)
        # Ensure the embedded app directory exists
        FileUtils.mkdir_p(embedded_apps_root)
        # Copy the application code into place
        FileUtils.cp_r("#{Omnibus::Config.source_dir}/#{app_name}", embedded_apps_root)
        # Delete any top-level `.git` directory
        FileUtils.rm_rf("#{embedded_app_dir}/.git")

        # Prepare the environment
        options[:env] ||= {}
        env = with_embedded_path || {}
        env["BUNDLE_GEMFILE"] = gemfile_lock
        options[:env].merge!(env)

        shellout!("#{appbundler_bin} '#{embedded_app_dir}' '#{bin_dir}'", options)
      end
    end
    expose :appbundle

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
        shellout!("#{bin} #{command}", options)
      end
    end
    expose :rake

    #
    # Execute the given Ruby block at runtime. The block is captured as-is and
    # no validation is performed. As a general rule, you should avoid this
    # method unless you know what you are doing.
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
        render_template(source_path,
          destination: dest,
          mode:        mode,
          variables:   vars,
        )
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
    # **These commands are run from inside {Software#project_dir}, so exercise
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
        Dir.chdir(software.project_dir) do
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
        Dir.chdir(software.project_dir) do
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
        Dir.chdir(software.project_dir) do
          FileSyncer.glob(path).each do |file|
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
      command = "copy `#{source}' to `#{destination}'"
      build_commands << BuildCommand.new(command) do
        Dir.chdir(software.project_dir) do
          files = FileSyncer.glob(source)
          if files.empty?
            log.warn(log_key) {"no matched files for glob #{command}"}
          else
            files.each do |file|
              FileUtils.cp_r(file, destination, options)
            end
          end
        end
      end
    end
    expose :copy

    #
    # Move the given source to the destination. This method accepts a single
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
      command = "move `#{source}' to `#{destination}'"
      build_commands << BuildCommand.new(command) do
        Dir.chdir(software.project_dir) do
          files = FileSyncer.glob(source)
          if files.empty?
            log.warn(log_key) {"no matched files for glob #{command}"}
          else
            files.each do |file|
              FileUtils.mv(file, destination, options)
            end
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
      command = "link `#{source}' to `#{destination}'"
      build_commands << BuildCommand.new(command) do
        Dir.chdir(software.project_dir) do
          files = FileSyncer.glob(source)
          if files.empty?
            log.warn(log_key) {"no matched files for glob #{command}"}
          else
            files.each do |file|
              FileUtils.ln_s(file, destination, options)
            end
          end
        end
      end
    end
    expose :link

    #
    # (see FileSyncer.sync)
    #
    # @example
    #   sync "#{project_dir}/**/*.rb", "#{install_dir}/ruby_files"
    #
    # @example
    #   sync project_dir, "#{install_dir}/files", exclude: '.git'
    #
    def sync(source, destination, options = {})
      build_commands << BuildCommand.new("sync `#{source}' to `#{destination}'") do
        Dir.chdir(software.project_dir) do
          FileSyncer.sync(source, destination, options)
        end
      end
    end
    expose :sync

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
      shasum # ensure shashum is calculated before build since the build can alter the shasum
      log.internal(log_key) { "Cached builder checksum before build: #{shasum}"}
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
    def shellout!(command_string, options = {})
      # Make sure the PWD is set to the correct directory
      options = { cwd: software.project_dir }.merge(options)

      # Set the log level to :info so users will see build commands
      options[:log_level] ||= :info

      # Set the live stream to :debug so users will see build output
      options[:live_stream] ||= log.live_stream(:debug)

      # Use Util's shellout
      super(command_string, options)
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
    #   - +CommandFailed+
    #   - +CommandTimeout+
    #
    # @param [Proc] block
    #   the block to execute
    #
    def with_retries(&block)
      tries = Config.build_retries
      delay = 5
      exceptions = [CommandFailed, CommandTimeout]

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
    # - _ORIGINAL_GEM_PATH
    # - GEM_PATH
    # - GEM_HOME
    # - GEM_ROOT
    # - BUNDLE_BIN_PATH
    # - BUNDLE_GEMFILE
    # - RUBYLIB
    # - RUBYOPT
    # - RUBY_ENGINE
    # - RUBY_ROOT
    # - RUBY_VERSION
    #
    # The original environment restored at the end of this call.
    #
    # @param [Proc] block
    #   the block to execute with the cleaned environment
    #
    def with_clean_env(&block)
      original = ENV.to_hash

      ENV.delete('_ORIGINAL_GEM_PATH')
      ENV.delete_if { |k,_| k.start_with?('BUNDLE_') }
      ENV.delete_if { |k,_| k.start_with?('GEM_') }
      ENV.delete_if { |k,_| k.start_with?('RUBY') }

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
      candidate_paths = Omnibus.possible_paths_for(path).map do |directory|
        File.join(directory, software.name, source)
      end

      file = candidate_paths.find { |path| File.exist?(path) }

      [candidate_paths, file]
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
    # Inspect the given command and warn if the command "looks" like it is a
    # shell command that has a DSL method. (like +command 'cp'+ versus +copy+).
    #
    # @param [String] command
    #   the command to check
    #
    # @return [void]
    #
    def warn_for_shell_commands(command)
      case command
      when /^cp /i
        log.warn(log_key) { "Detected command `cp'. Consider using the `copy' DSL method." }
      when /^rubocopy /i
        log.warn(log_key) { "Detected command `rubocopy'. Consider using the `sync' DSL method." }
      when /^mv /i
        log.warn(log_key) { "Detected command `mv'. Consider using the `move' DSL method." }
      when /^rm /i
        log.warn(log_key) { "Detected command `rm'. Consider using the `delete' DSL method." }
      when /^remove /i
        log.warn(log_key) { "Detected command `remove'. Consider using the `delete' DSL method." }
      when /^rsync /i
        log.warn(log_key) { "Detected command `rsync'. Consider using the `sync' DSL method." }
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
