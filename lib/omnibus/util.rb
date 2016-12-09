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
        case result.length
        when 0
          raise "The current omnibus environment has no PATH"
        when 1
          result.first
        else
          raise "The current omnibus environment has multiple PATH/Path variables."
        end
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
      in_msys = options.delete(:in_msys_bash) && ENV["MSYSTEM"]
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

      # Log any environment options given
      unless options[:environment].empty?
        log.public_send(log_level, log_key) { "Environment:" }
        options[:environment].sort.each do |key, value|
          log.public_send(log_level, log_key) { "  #{key}=#{value.inspect}" }
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
    # Retry the given block if a retriable exception is
    # raised. Returns the value of the block call if successful.
    #
    # @param [String] logstr
    #   Description of the action being retried. Used in log output.
    #
    # @param [Array<Exception>] retried_exceptions
    #   List of exceptions to retry.  Any other exceptions are raisesd.
    #
    # @param [Integer] retries
    #   Number of times to retry the given block.
    #
    def retry_block(logstr, retried_exceptions = [], retries = Omnibus::Config.fetcher_retries, &block)
      begin
        yield
      rescue Exception => e
        raise e unless retried_exceptions.any? { |eclass| e.is_a?(eclass) }
        if retries != 0
          log.info(log_key) { "Retrying failed #{logstr} due to #{e} (#{retries} retries left)..." }
          retries -= 1
          retry
        else
          log.error(log_key) { "#{logstr} failed - #{e.class}!" }
          raise
        end
      end
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
    # Convert the given path to be appropriate for usage with the given compiler
    #
    # @param [String, Array<String>] pieces
    #   the pieces of the path to join and fix
    # @return [String]
    #   the path with applied changes
    #
    def compiler_safe_path(*pieces)
      path = File.join(*pieces)
      path = path.sub(/^([A-Za-z]):\//, "/\\1/") if ENV["MSYSTEM"]
      path
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
  end
end
