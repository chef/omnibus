#
# Copyright:: Copyright (c) 2012 Opscode, Inc.
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
require 'omnibus/version'

require 'fileutils'
require 'thor'

module Omnibus
  class CLI < Thor

    # Constructs a new instance.
    def initialize(*args)
      super
      $stdout.sync = true
    end

    class_option :config,
      :aliases => [:c],
      :type => :string,
      :default => File.join(Dir.pwd, Omnibus::DEFAULT_CONFIG_FILENAME),
      :desc => "Path to Omnibus configuration to use."

    method_option :timestamp,
      :aliases => [:t],
      :type => :boolean,
      :default => true,
      :desc => "Append timestamp information to the version identifier? Add a timestamp for build versions; leave it off for release and pre-release versions"
    method_option :path,
      :aliases => [:p],
      :type => :string,
      :default => Dir.pwd,
      :desc => "Path to Omnibus project root."
    desc "build PROJECT", "Build the given Omnibus project"
    def build(project)
      load_omnibus_projects!(options[:path], options[:config])
      project_task_name = "projects:#{project}"

      if Rake::Task.task_defined?(project_task_name)
        say("Building #{project}", :green)
        unless options[:timestamp]
          say("I won't append a timestamp to the version identifier.", :yellow)
        end

        # Until we have time to integrate the CLI deeply into the Omnibus codebase
        # this will have to suffice! (sadpanda)
        ENV['OMNIBUS_APPEND_TIMESTAMP'] = options[:timestamp].to_s

        Rake::Task[project_task_name].invoke
      else
        project_names = Omnibus.projects.map{|p| p.name}
        error_msg = "I don't know anythinga about project '#{project}'. \n"
        error_msg << "Valid project names include: #{project_names.join(', ')}"
        raise Thor::Error, error_msg
      end
    end

    desc "version", "Display version information"
    def version
      say("Omnibus: #{Omnibus::VERSION}", :yellow)
    end

    private

    # Forces command to exit with a 1 on any failure...so raise away.
    def self.exit_on_failure?
      true
    end

    def load_omnibus_projects!(path, config_file=nil)
      unless Dir["#{path}/config/projects/*.rb"].any?
        raise Thor::Error, "Given path '#{path}' does not appear to be a valid Omnibus project root."
      end

      config_file_contents = nil

      begin
        if config_file && File.exist?(config_file)
          config_file_contents = IO.read(config_file)
          eval(config_file_contents)
          say("Using Omnibus configuration file #{config_file}", :green)
        else
          Omnibus.configure
        end
      rescue => e
        error_msg = "Something went wrong loading the Omnibus project!"
        if config_file

          error_msg << <<-CONFIG

Configuration file location:

\t#{config_file}

Configuration file contents:

#{config_file_contents}
CONFIG
        end

      error_msg << <<-ERROR

Error raised was: #{$!}

Backtrace:
\t#{e.backtrace.join("\n\t")}

        ERROR
        raise Thor::Error, error_msg
      end
    end

  end
end
