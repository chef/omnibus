#
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

require 'omnibus/util'
require 'thor'

module Omnibus
  module CLI
    class Base < Thor
      include Thor::Actions

      class_option :config,
        :aliases => [:c],
        :type => :string,
        :default => File.join(Dir.pwd, Omnibus::DEFAULT_CONFIG_FILENAME),
        :desc => "Path to the Omnibus configuration file to use."
      class_option :path,
        :aliases => [:p],
        :type => :string,
        :default => Dir.pwd,
        :desc => "Path to the Omnibus project root."

      def initialize(*args)
        super
        $stdout.sync = true
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
        if (self.namespace.split(':').last != 'application') || self.subcommands.empty?
          subcommand = true
        end
        "#{basename} #{command.formatted_usage(self, $thor_runner, subcommand)}"
      end

      protected

      ##################################################################
      # Omnibus Helpers (should these be in Omnibus::Util?)
      ##################################################################

      def load_project!(project_name)
        project = Omnibus.project(project_name)
        unless project
          error_msg = "\nI don't know anythinga about project '#{project_name}'. \n\n"
          error_msg << "Valid project names include: #{Omnibus.project_names.join(', ')}\n"
          raise Omnibus::CLI::Error, set_color(error_msg, :red)
        end
        project
      end

      def load_omnibus_projects!(path, config_file=nil)

        if config_file && File.exist?(config_file)
          say("Using Omnibus configuration file #{config_file}", :green)
          Omnibus.load_configuration(config_file)
        end

        # TODO: merge in all relevant CLI options here, as they should
        # override anything from a configuration file.
        Omnibus::Config.project_root path

        unless Omnibus.project_files.any?
          raise Omnibus::CLI::Error, "Given path '#{path}' does not appear to be a valid Omnibus project root."
        end

        begin
          Omnibus.process_configuration
        rescue => e
          error_msg = "Something went wrong loading the Omnibus projects.\n"

          if File.exist?(config_file)

            error_msg << <<-CONFIG

  Configuration file location:

  \t#{config_file}

  Configuration file contents:

  #{config_file_contents}
  CONFIG
          end

        error_msg << <<-ERROR

  Error raised was:

  \t#{$!}

  Backtrace:

  \t#{e.backtrace.join("\n\t")}

          ERROR
          raise Omnibus::CLI::Error, set_color(error_msg, :red)
        end
      end

    end
  end
end
