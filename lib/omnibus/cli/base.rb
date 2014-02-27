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

require 'omnibus/util'
require 'thor'

module Omnibus
  module CLI
    class Base < Thor
      include Thor::Actions

      class_option :config,
                   aliases: [:c],
                   type: :string,
                   default: File.join(Dir.pwd, Omnibus::DEFAULT_CONFIG_FILENAME),
                   desc: 'Path to the Omnibus configuration file to use.'

      def initialize(args, options, config)
        super(args, options, config)
        $stdout.sync = true

        # Don't try to initialize the Omnibus project for help commands.#
        # current_task renamed to current_command in Thor 0.18.0
        current_command = config[:current_command] ? config[:current_command].name : config[:current_task].name
        return if current_command == 'help'

        if (config = @options[:config])
          if config && File.exist?(@options[:config])
            say("Using Omnibus configuration file #{config}", :green)
            Omnibus.load_configuration(config)
          elsif config
            say("No configuration file `#{config}', using defaults", :yellow)
          end
        end

        if (path = @options[:path])
          # TODO: merge in all relevant CLI options here, as they should
          # override anything from a configuration file.
          Omnibus::Config.project_root(path)
          Omnibus::Config.append_timestamp(@options[:timestamp]) if @options.key?('timestamp')

          unless Omnibus.project_files.any?
            fail Omnibus::CLI::Error, "Given path '#{path}' does not appear to be a valid Omnibus project root."
          end

          begin
            Omnibus.process_configuration
          rescue => e
            error_msg = 'Could not load the Omnibus projects.'
            raise Omnibus::CLI::Error.new(error_msg, e)
          end
        end
      end

      ##################################################################
      # Thor Overrides/Tweaks
      ##################################################################

      # Used by {Thor::Actions#template} to locate ERB templates
      # @return [String]
      def self.source_root
        File.expand_path(File.join(File.dirname(__FILE__), '..', 'templates'))
      end

      # Forces command to exit with a 1 on any failure...so raise away.
      def self.exit_on_failure?
        true
      end

      # For some strange reason the +subcommand+ argument is disregarded when
      # +Thor.banner+ is called by +Thor.command_help+:
      #
      #   https://github.com/wycats/thor/blob/master/lib/thor.rb#L163-L164
      #
      # We'll override +Thor.banner+ and ensure subcommand is true when called
      # for subcommands.
      def self.banner(command, namespace = nil, subcommand = false)
        # Main commands have an effective namespace of 'application' OR
        # contain subcommands
        subcommand = self.namespace.split(':').last != 'application' || subcommands.empty?
        "#{basename} #{command.formatted_usage(self, $thor_runner, subcommand) }"
      end

      protected

      ##################################################################
      # Omnibus Helpers (should these be in Omnibus::Util?)
      ##################################################################

      def load_project!(project_name)
        project = Omnibus.project(project_name)
        unless project
          error_msg = "I don't know anything about project '#{project_name}'."
          error_msg << " Valid project names include: #{Omnibus.project_names.join(', ') }"
          fail Omnibus::CLI::Error, error_msg
        end
        project
      end
    end
  end
end
