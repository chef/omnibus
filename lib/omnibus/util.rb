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
  module Util
    #
    # The default shellout options.
    #
    # @return [Hash]
    #
    SHELLOUT_OPTIONS = {
      live_stream: Omnibus.logger.live_stream(:debug),
      timeout: 7200, # 2 hours
      environment: {},
    }.freeze

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
    #   which which has +stdout+, +stderr+, +status+, and +exitstatus+
    #   populated with results of the command.
    #
    def shellout(*args)
      options = args.last.kind_of?(Hash) ? args.pop : {}
      options = SHELLOUT_OPTIONS.merge(options)

      # Log any environment options given
      unless options[:environment].empty?
        Omnibus.logger.info { 'Environment:' }
        options[:environment].each do |key, value|
          Omnibus.logger.info { "  #{key.to_s.upcase}=#{value.inspect}" }
        end
      end

      # Log the actual command
      Omnibus.logger.info { "$ #{args.join(' ')}" }

      cmd = Mixlib::ShellOut.new(*args, options)
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

    # Return true if the given value appears to be "truthy".
    #
    # @param [#to_s] value
    def truthy?(value)
      value && value.to_s =~ /^(true|t|yes|y|1)$/i
    end

    # Return true if the given value appears to be "falsey".
    #
    # @param [#to_s] value
    def falsey?(value)
      value && value.to_s =~ /^(false|f|no|n|0)$/i
    end

    # @param [Array<String>] pieces
    #   the pieces of the path to join and fix
    # @return [String]
    #   the path with applied changes
    #
    def windows_safe_path(*pieces)
      path = File.expand_path(File.join(*pieces))

      if File::ALT_SEPARATOR
        path.gsub(File::SEPARATOR, File::ALT_SEPARATOR)
      else
        path
      end
    end
  end
end
