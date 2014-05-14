#
# Copyright 2014 Chef Software, Inc.
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

require 'pp'

module Omnibus
  module Overrides
    include Logging

    DEFAULT_OVERRIDE_FILE_NAME = 'omnibus.overrides'

    class << self
      # Parses a file of override information into a Hash.
      #
      # Each line of the file must be of the form
      #
      #
      #     <package_name> <version>
      #
      # where the two pieces of data are separated by whitespace.
      #
      # @param file [String] the path to an overrides file
      # @return [Hash, nil]
      def parse_file(file)
        if file
          File.readlines(file).reduce({}) do |acc, line|
            info = line.split

            unless info.count == 2
              raise ArgumentError, "Invalid overrides line: '#{line.chomp}'"
            end

            package, version = info

            if acc[package]
              raise ArgumentError, "Multiple overrides present for '#{package}' in overrides file #{file}!"
            end

            acc[package] = version
            acc
          end
        else
          nil
        end
      end

      # Return the full path to an overrides file, or +nil+ if no such
      # file exists.
      def resolve_override_file
        file = ENV['OMNIBUS_OVERRIDE_FILE'] || DEFAULT_OVERRIDE_FILE_NAME
        path = File.expand_path(file)
        File.exist?(path) ? path : nil
      end

      # Return a hash of override information.  If no such information
      # can be found, the hash will be empty
      #
      # @return [Hash]
      def overrides
        file = resolve_override_file
        overrides = parse_file(file)

        if overrides
          log.info(log_key) do
            out = "Using overrides from #{resolve_override_file}\n"
            out << overrides.pretty_inspect
            out
          end
        end

        overrides || {}
      end
    end
  end
end
