#
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Copyright:: Copyright (c) 2013 Opscode, Inc.
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
  # @author Seth Chisamore (<schisamo@opscode.com>)
  #
  module Util
    # Shells out and runs +command+.
    #
    # @param command [String]
    # @param opts [Hash] the options passed to the initializer of the
    #   +Mixlib::ShellOut+ instance.
    # @return [Mixlib::ShellOut] the underlying +Mixlib::ShellOut+ instance
    #   which which has +stdout+, +stderr+, +status+, and +exitstatus+
    #   populated with results of the command.
    #
    def shellout(command, opts={})
      STDOUT.sync = true
      default_options = {
        :live_stream => STDOUT,
        :timeout => 7200, # 2 hours
        :environment => {}
      }
      cmd = Mixlib::ShellOut.new(command, default_options.merge(opts))
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
    def shellout!(command, opts={})
      cmd = shellout(command, opts)
      cmd.error!
      cmd
    end
  end
end
