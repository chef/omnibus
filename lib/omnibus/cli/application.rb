#
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

require 'omnibus'
require 'omnibus/cli/base'
require 'omnibus/cli/build'
require 'omnibus/cli/cache'
require 'omnibus/cli/release'

module Omnibus
  module CLI
    class Application < Base
      ###########################################################################
      # Subcommands
      ###########################################################################

      desc 'build [COMMAND]', 'Perform build-related tasks'
      subcommand 'build', Omnibus::CLI::Build

      desc 'cache [COMMAND]', 'Perform cache management tasks'
      subcommand 'cache', Omnibus::CLI::Cache

      desc 'release [COMMAND]', 'Perform release tasks'
      subcommand 'release', Omnibus::CLI::Release

      ###########################################################################
      # Class Methods
      ###########################################################################

      # Override start so we can catch and process any exceptions bubbling up
      def self.start(*args)
        super
      rescue => e
        error_msg = 'Something went wrong...the Omnibus just ran off the road!'
        error_msg << "\n\nError raised was:\n\n\t#{e}"
        error_msg << "\n\nBacktrace:\n\n\t#{e.backtrace.join("\n\t") }"
        if e.respond_to?(:original) && e.original
          error_msg << "\n\nOriginal Error:\n\n\t#{e.original}"
          error_msg << "\n\nOriginal Backtrace:\n\n\t#{e.original.backtrace.join("\n\t") }"
        end
        # TODO: we need a proper UI class
        Thor::Base.shell.new.say(error_msg, :red)
        exit 1
      end
    end
  end
end
