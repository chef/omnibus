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
    include Omnibus::Util
    include Thor::Actions

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
    class_option :path,
      :aliases => [:p],
      :type => :string,
      :default => Dir.pwd,
      :desc => "Path to Omnibus project root."

    method_option :timestamp,
      :aliases => [:t],
      :type => :boolean,
      :default => true,
      :desc => "Append timestamp information to the version identifier? Add a timestamp for build versions; leave it off for release and pre-release versions"
    desc "build PROJECT", "Build the given Omnibus project"
    def build(project_name)
      load_omnibus_projects!(options[:path], options[:config])
      project = load_project!(project_name)
      project_task_name = "projects:#{project.name}"

      say("Building #{project}", :green)
      unless options[:timestamp]
        say("I won't append a timestamp to the version identifier.", :yellow)
      end

      # Until we have time to integrate the CLI deeply into the Omnibus codebase
      # this will have to suffice! (sadpanda)
      ENV['OMNIBUS_APPEND_TIMESTAMP'] = options[:timestamp].to_s

      Rake::Task[project_task_name].invoke
    end

    method_option :purge,
      :type => :boolean,
      :default => false,
      :desc => "Remove ALL files generated during the build (including packages)."
    desc "clean PROJECT", "Remove temporary files generated during the build process."
    def clean(project_name)
      load_omnibus_projects!(options[:path], options[:config])
      project = load_project!(project_name)

      deletion_list = []
      deletion_list << Dir.glob("#{Omnibus.config.source_dir}/**/*")
      deletion_list << Dir.glob("#{Omnibus.config.build_dir}/**/*")

      if options[:purge]
        deletion_list << Dir.glob("#{Omnibus.config.package_dir}/**/*")
        deletion_list << Dir.glob("#{Omnibus.config.cache_dir}/**/*")
        deletion_list << project.install_path if File.exist?(project.install_path)
      end

      deletion_list.flatten!
      deletion_list.each{|f| remove_file(f) }
    end

    desc "project PROJECT", "Creates a skeletal Omnibus project"
    def project(name)
      target = File.join(Dir.pwd, name)
      install_path = File.join("/opt", name)
      opts = {
        :name => name,
        :install_path => install_path
      }

      create_file(File.join(target, "config", "software", "README.md"),
                  "Software definitions for your project's dependencies go here!")
      template(File.join("Gemfile.erb"), File.join(target, "Gemfile"), opts)
      template(File.join("gitignore.erb"), File.join(target, ".gitignore"), opts)
      template(File.join("project.rb.erb"), File.join(target, "config", "projects", "#{name}.rb"), opts)
      template(File.join("README.md.erb"), File.join(target, "README.md"), opts)

      # render out stub packge scripts
      %w{ makeselfinst postinst postrm }.each do |package_script|
        script_path = File.join(target, "package-scripts", name, package_script)
        template_path = File.join("package_scripts", "#{package_script}.erb")
        # render the package script
        template(template_path, script_path, opts)
        # ensure the package script is executable
        FileUtils.chmod(0755, script_path)
      end
    end

    desc "version", "Display version information"
    def version
      say("Omnibus: #{Omnibus::VERSION}", :yellow)
    end

    private

    # Used by `Thor::Actions#template` to locate ERB templates
    def self.source_root
      File.expand_path(File.join(File.dirname(__FILE__), 'templates'))
    end

    # Forces command to exit with a 1 on any failure...so raise away.
    def self.exit_on_failure?
      true
    end

    def load_project!(project_name)
      project = Omnibus.project(project_name)
      unless project
        error_msg = "\nI don't know anythinga about project '#{project_name}'. \n\n"
        error_msg << "Valid project names include: #{Omnibus.project_names.join(', ')}\n"
        raise Thor::Error, set_color(error_msg, :red)
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
        raise Thor::Error, "Given path '#{path}' does not appear to be a valid Omnibus project root."
      end

      begin
        Omnibus.process_configuration
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
