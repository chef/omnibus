#
# Author:: Seth Chisamore (<schisamo@getchef.com>)
# Copyright:: Copyright (c) 2013-2014 Chef Software, Inc.
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

require 'mixlib/shellout'

module Omnibus
  #
  # @author Seth Chisamore (<schisamo@getchef.com>)
  #
  module Util
    # Shells out and runs +command+.
    #
    # @overload shellout(command, opts={})
    #   @param command [String]
    #   @param opts [Hash] the options passed to the initializer of the
    #     +Mixlib::ShellOut+ instance.
    # @overload shellout(command_fragments, opts={})
    #   @param command [Array<String>] command argv as individual strings
    #   @param opts [Hash] the options passed to the initializer of the
    #     +Mixlib::ShellOut+ instance.
    # @return [Mixlib::ShellOut] the underlying +Mixlib::ShellOut+ instance
    #   which which has +stdout+, +stderr+, +status+, and +exitstatus+
    #   populated with results of the command.
    #
    def shellout(*command_fragments)
      STDOUT.sync = true

      opts = if command_fragments.last.kind_of?(Hash)
               command_fragments.pop
             else
               {}
             end

      default_options = {
        live_stream: STDOUT,
        timeout: 7200, # 2 hours
        environment: {},
      }
      cmd = Mixlib::ShellOut.new(*command_fragments, default_options.merge(opts))
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
    def shellout!(*command_fragments)
      cmd = shellout(*command_fragments)
      cmd.error!
      cmd
    end
  end
end
