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

require 'bundler'
require 'fileutils'
require 'mixlib/shellout'

module Omnibus
  class Builder
    include Cleanroom
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

      if target
        command = "cat #{patch_path} | patch -p#{plevel} #{target}"
      else
        command = "patch -d #{software.project_dir} -p#{plevel} -i #{patch_path}"
      end

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
        _shellout!("#{install_dir}/embedded/bin/ruby #{command}", options)
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
        _shellout!("#{install_dir}/embedded/bin/gem #{command}", options)
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
        _shellout!("#{install_dir}/embedded/bin/bundle #{command}", options)
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
        _shellout!("#{install_dir}/embedded/bin/rake #{command}", options)
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
      locations, source = find_file('config/templates', options[:source])

      unless source
        raise MissingTemplate.new(options[:source], locations)
      end

      block "Render erb `#{options[:source]}'" do
        template = ERB.new(File.new(source_path).read, nil, '%')
        File.open(options[:dest], 'w') do |file|
          file.write(template.result(OpenStruct.new(options[:vars]).instance_eval { binding }))
        end

        File.chmod(options[:mode], options[:dest])
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
    # Touch the given filepath at runtime.
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
          FileUtils.touch(file, options)
        end
      end
    end
    expose :touch

    #
    # Delete the given file or directory on the system. This method uses the
    # equivalent of +rm -rf+.
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
          FileUtils.rm_rf(path, options)
        end
      end
    end
    expose :delete

    #
    # Copy the given source to the destination.
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
          FileUtils.cp_r(source, destination, options)
        end
      end
    end
    expose :copy

    #
    # Copy the given source to the destination.
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
          FileUtils.mv(source, destination, options)
        end
      end
    end
    expose :move

    #
    # Link the given source to the destination.
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
          FileUtils.ln_s(source, destination, options)
        end
      end
    end
    expose :link

    #
    # @!endgroup
    # --------------------------------------------------

    #
    # @!group Deprecated DSL methods
    #
    # The following DSL methods are available from within build blocks, but are
    # deprecated and will be removed in the next major release.
    # --------------------------------------------------

    #
    # @deprecated Use {Config.project_root} instead
    #
    def project_root
      Omnibus.logger.deprecated(log_key) do
        'project_root (DSL). Please use Config.project_root instead.'
      end

      Config.project_root
    end
    expose :project_root

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
    # The **in-order** list of commands for this builder. Note that procs have
    # not been evaluated at this stage.
    #
    # @return [Array<BuildCommand>]
    #
    def build_commands
      @build_commands ||= []
    end

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
    # @!endgroup
    # --------------------------------------------------

    private

    #
    # This is a helper method that wraps {Util#shellout!} for the purposes of
    # making path's Windows appropriate and setting the +:cwd+ value.
    #
    # @see (Util#shellout!)
    #
    def _shellout!(command_string, options = {})
      # Convert paths to Windows, if necessary
      command_string = windows_safe_path(command_string)

      # Make sure the PWD is set to the correct directory
      options = { cwd: software.project_dir }.merge(options)

      # Use Util's shellout
      shellout!(command_string, options)
    end

    #
    #
    #
    def execute(command)
      Bundler.with_clean_env do
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
    # The log key for this class, overriden to incorporate the software name.
    #
    # @return [String]
    #
    def log_key
      @log_key ||= "#{super}: #{software.name}"
    end

    #
    #
    #
    class BuildCommand
      attr_reader :description

      def initialize(description, &block)
        @description, @block = description, block
      end

      def run(object)
        object.instance_eval(&@block)
      end
    end
  end
end
