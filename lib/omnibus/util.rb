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

require 'mixlib/shellout'

module Omnibus
  #
  # @author Seth Chisamore (<schisamo@getchef.com>)
  #
  module Util
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
    #   which which has +stdout+, +stderr+, +status+, and +exitstatus+
    #   populated with results of the command.
    #
    def shellout(*args)
      options = args.last.kind_of?(Hash) ? args.pop : {}

      default_options = {
        live_stream: STDOUT,
        timeout: 7200, # 2 hours
        environment: {},
      }

      cmd = Mixlib::ShellOut.new(*args, default_options.merge(options))
      cmd.run_command
      cmd
    end

    # Similar to +shellout+ method except it raises an exception if the
    # command fails.
    #
    # @see #shellout
    #
    # @raise [Mixlib::ShellOut::ShellCommandFailed] if +exitstatus+ is not in
    #   the list of +valid_exit_codes+.
    #
    def shellout!(*args)
      cmd = shellout(*args)
      cmd.error!
      cmd
    end

    #
    # Run a command in subshell, suppressing any output.
    #
    # @see (Util#shellout)
    #
    def quiet_shellout(*args)
      options = args.last.kind_of?(Hash) ? args.pop : {}
      options[:live_stream] = nil
      args << options
      shellout(*args)
    end

    #
    # Run a command, suppressing any output, but raising an error if the
    # command fails.
    #
    # @see (Util#shellout!)
    #
    def quiet_shellout!(*args)
      options = args.last.kind_of?(Hash) ? args.pop : {}
      options[:live_stream] = nil
      args << options
      shellout!(*args)
    end

    # Replaces path separators with alternative ones when needed.
    #
    # @param path [String]
    # @return [String] given path with applied changes.
    #
    def windows_safe_path!(path)
      path.gsub!(File::SEPARATOR, File::ALT_SEPARATOR) if File::ALT_SEPARATOR
    end
  end
end
