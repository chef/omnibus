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

#
# This is the base class that all commands and subcommands should extend from.
# It handles all of the Thor nastiness and method mutating, as well as defining
# the global configuration options.
#
module Omnibus
  class Command::Base < Thor
    class << self
      def dispatch(m, args, options, config)
        # Handle the case where Thor thinks a trailing --help is actually an
        # argument and blows up...
        if args.length > 1 && !(args & Thor::HELP_MAPPINGS).empty?
          args = args - Thor::HELP_MAPPINGS
          args.insert(-2, "help")
        end

        super
      end
    end

    include Logging

    def initialize(args, options, config)
      super(args, options, config)

      # Set the log_level
      if @options[:log_level]
        Omnibus.logger.level = @options[:log_level]
      end

      # Do not load the Omnibus config if we are asking for help or the version
      if %w{help version}.include?(config[:current_command].name)
        log.debug(log_key) { "Skipping Omnibus loading (detected help or version)" }
        return
      end

      if File.exist?(@options[:config])
        log.info(log_key) { "Using config from '#{@options[:config]}'" }
        Omnibus.load_configuration(@options[:config])
      else
        if @options[:config] == Omnibus::DEFAULT_CONFIG
          log.debug(log_key) { "Config file not given - using defaults" }
        else
          raise "The given config file '#{@options[:config]}' does not exist!"
        end
      end

      @options[:override].each do |key, value|
        if %w{true false nil}.include?(value)
          log.debug(log_key) { "Detected #{value.inspect} should be an object" }
          value = { "true" => true, "false" => false, "nil" => nil }[value]
        end

        if value =~ /\A[[:digit:]]+\Z/
          log.debug(log_key) { "Detected #{value.inspect} should be an integer" }
          value = value.to_i
        end

        if Config.respond_to?(key)
          log.debug(log_key) { "Setting Config.#{key} = #{value.inspect}" }
          Config.send(key, value)
        else
          log.debug (log_key) { "Skipping option '#{key}' - not a config option" }
        end
      end
    end

    class_option :config,
                 desc: "Path to the Omnibus config file",
                 aliases: "-c",
                 type: :string,
                 default: Omnibus::DEFAULT_CONFIG
    class_option :log_level,
                 desc: "The log level",
                 aliases: "-l",
                 type: :string,
                 enum: Logger::LEVELS.map(&:downcase),
                 default: "info"
    class_option :override,
                 desc: "Override one or more Omnibus config options",
                 aliases: "-o",
                 type: :hash,
                 default: {}

    #
    # Hide the default help task to encourage people to use +-h+ instead of
    # Thor's dumb way of asking for help.
    #
    desc "help [COMMAND]", "Show help output", hide: true
    def help(*)
      super
    end
  end
end
