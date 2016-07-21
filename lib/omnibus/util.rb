#
# Copyright 2013-2014 Chef Software, Inc.
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

require "mixlib/shellout"

module Omnibus
  module Util
    def self.included(base)
      # This module requires logging is also available
      base.send(:include, Logging)
      base.send(:include, Sugarable)
    end

    #
    # The default shellout options.
    #
    # @return [Hash]
    #
    SHELLOUT_OPTIONS = {
      log_level: :internal,
      timeout: 7200, # 2 hours
      environment: {},
    }.freeze

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
      #
      # Turns out there is other build environments that only set ENV['PATH'] and if we
      # modify ENV['Path'] then it ignores that.  So, we scan ENV and returns the first
      # one that we find.
      #
      if windows?
        result = ENV.keys.grep(/\Apath\Z/i)
        raise "The current omnibus environment has no PATH" if result.length == 0
        raise "The current omnibus environment has duplicate PATHs" if result.length > 1
        result.first
      else
        "PATH"
      end
    end

    #
    # Shells out and runs +command+.
    #
    # @overload shellout(command, options = {})
    #   @param command [String]
    #   @param options [Hash] the options passed to the initializer of the
    #     +Mixlib::ShellOut+ instance.
    # @overload shellout(command_fragments, options = {})
    #   @param command [Array<String>] command argv as individual strings
    #   @param options [Hash] the options passed to the initializer of the
    #     +Mixlib::ShellOut+ instance.
    # @return [Mixlib::ShellOut] the underlying +Mixlib::ShellOut+ instance
    #   which has +stdout+, +stderr+, +status+, and +exitstatus+
    #   populated with results of the command.
    #
    def shellout(*args)
      options = args.last.kind_of?(Hash) ? args.pop : {}
      options = SHELLOUT_OPTIONS.merge(options)

      command_string = args.join(" ")
      in_msys = options.delete(:in_msys_bash) && windows?
      # Mixlib will handle escaping characters for cmd but our command might
      # contain '. For now, assume that won't happen because I don't know
      # whether this command is going to be played via cmd or through
      # ProcessCreate.
      command_string = "bash -c \'#{command_string}\'" if in_msys

      # Grab the log_level
      log_level = options.delete(:log_level)

      # Set the live stream if one was not given
      options[:live_stream] ||= log.live_stream(:internal)

      # Since Mixlib::ShellOut supports :environment and :env, we want to
      # standardize here
      if options[:env]
        options[:environment] = options.fetch(:environment, {}).merge(options[:env])
      end

      # Double check that we don't have conflicting PATH definitions.
      path_keys = options[:environment].keys.grep(/\Apath\Z/i)
      if path_keys.length > 1
        raise InvalidValue.new("shellout", "receive environment without duplicate PATH values")
      elsif path_keys.length == 1 && path_keys.first != path_key
        options[:environment][path_key] = options[:environment].delete(path_keys.first)
      end

      # Try our best to get rid of the "outer" omnibus ruby and any current
      # chef-client/chef-dk installations from the path.
      if options.delete(:clean_ruby_path)
        path_dirs = options[:environment].fetch(path_key, "").split(File::PATH_SEPARATOR || ":")
        path_dirs = path_dirs.reject do |p|
          filter_paths.any? { |f| windows_safe_path(p).start_with?(f) }
        end
        options[:environment][path_key] = path_dirs.join(File::PATH_SEPARATOR || ":")
      end

      # Log any environment options given
      unless options[:environment].empty?
        log.public_send(log_level, log_key) { "Environment:" }
        if in_msys
          # Run a command to log the actual environment variables inside the
          # msys shell. Live stream at the same level we would have otherwise
          # logged the environment at.
          env_options = options.dup
          env_options[:live_stream] = log.live_stream(log_level || :info)
          env_cmds = options[:environment].keys.sort.map do |key|
            # Special case "PATH" because it's capitalized and handled differently.
            key = "PATH" if key == path_key
            "echo #{key}=$#{key}"
          end
          env_cmds << "echo PWD=$PWD"

          cmd = Mixlib::ShellOut.new("bash -c \'#{env_cmds.join(';')}\'", env_options)
          cmd.environment["HOME"] = "/tmp" unless ENV["HOME"]
          cmd.run_command
        else
          options[:environment].sort.each do |key, value|
            log.public_send(log_level, log_key) { "  #{key}=#{value.inspect}" }
          end
        end
      end

      # Log the actual command
      log.public_send(log_level, log_key) { "$ #{command_string}" }

      cmd = Mixlib::ShellOut.new(command_string, options)
      cmd.environment["HOME"] = "/tmp" unless ENV["HOME"]
      cmd.run_command
      cmd
    end

    #
    # Similar to +shellout+ method except it raises an exception if the
    # command fails.
    #
    # @see #shellout
    #
    # @raise [CommandFailed]
    #   if +exitstatus+ is not in the list of +valid_exit_codes+
    # @raise [CommandTimeout]
    #   if execution time exceeds +timeout+
    #
    def shellout!(*args)
      cmd = shellout(*args)
      cmd.error!
      cmd
    rescue Mixlib::ShellOut::ShellCommandFailed
      raise CommandFailed.new(cmd)
    rescue Mixlib::ShellOut::CommandTimeout
      raise CommandTimeout.new(cmd)
    end

    #
    # Convert the given path to be appropiate for shelling out on Windows.
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

    #
    # Create a directory at the given +path+.
    #
    # @param [String, Array<String>] paths
    #   the path or list of paths to join to create
    #
    # @return [String]
    #   the path to the created directory
    #
    def create_directory(*paths)
      path = File.join(*paths)
      log.debug(log_key) { "Creating directory `#{path}'" }
      FileUtils.mkdir_p(path)
      path
    end

    #
    # Remove the directory at the given +path+.
    #
    # @param [String, Array<String>] paths
    #   the path or list of paths to join to delete
    #
    # @return [String]
    #   the path to the removed directory
    #
    def remove_directory(*paths)
      path = File.join(*paths)
      log.debug(log_key) { "Remove directory `#{path}'" }
      FileUtils.rm_rf(path)
      path
    end

    #
    # Copy the +source+ file to the +destination+.
    #
    # @param [String] source
    # @param [String] destination
    #
    # @return [String]
    #   the destination path
    #
    def copy_file(source, destination)
      log.debug(log_key) { "Copying `#{source}' to `#{destination}'" }
      FileUtils.cp(source, destination)
      destination
    end

    #
    # Remove the file at the given path.
    #
    # @param [String, Array<String>] paths
    #   the path or list of paths to join to delete
    #
    # @return [String]
    #   the path to the removed file
    #
    def remove_file(*paths)
      path = File.join(*paths)
      log.debug(log_key) { "Removing file `#{path}'" }
      FileUtils.rm_f(path)
      path
    end

    #
    # Create a file at the given path. If a block is given, the contents of the
    # block are written to the file. If the block is not given, the file is
    # simply "touched".
    #
    # @param [String, Array<String>] paths
    #   the path or list of paths to join to create
    #
    # @return [String]
    #   the path to the created file
    #
    def create_file(*paths, &block)
      path = File.join(*paths)
      log.debug(log_key) { "Creating file `#{path}'" }

      FileUtils.mkdir_p(File.dirname(path))

      if block
        File.open(path, "wb") { |f| f.write(yield) }
      else
        FileUtils.touch(path)
      end

      path
    end

    #
    # Create a symlink from a to b
    #
    # @param [String] a
    # @param [String] b
    #
    def create_link(a, b)
      log.debug(log_key) { "Linking `#{a}' to `#{b}'" }
      FileUtils.ln_s(a, b)
    end

    private

    def filter_paths
      @filter_paths ||=
        begin
          # Any alternate binaries or gems from the users environment.
          filters = Gem.paths.path.dup
          # Any possible embedded ruby in chef products.
          if windows?
            filters << "C:/opscode"
          else
            filters << "/opt/chef" << "/opt/chefdk" << "/opt/delivery-cli"
          end
          # Current ruby - this is the ruby that omnibus itself uses.
          filters << File.expand_path(File.join(RbConfig.ruby, "../.."))
          filters.map { |p| windows_safe_path(p) }
        end
    end
  end
end
