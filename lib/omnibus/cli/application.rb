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
      method_option :purge,
                    type: :boolean,
                    default: false,
                    desc: 'Remove ALL files generated during the build (including packages).'
      method_option :path,
                    aliases: [:p],
                    type: :string,
                    default: Dir.pwd,
                    desc: 'Path to the Omnibus project root.'
      desc 'clean PROJECT', 'Remove temporary files generated during the build process.'
      def clean(project_name)
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
        deletion_list.each { |f| remove_file(f) }
      end

      desc 'project PROJECT', 'Creates a skeletal Omnibus project'
      def project(name)
        name = name.chomp('/') # remove trailing slash if present
        target = File.join(Dir.pwd, "omnibus-#{name}")
        install_path = File.join('/opt', name)
        opts = {
          name: name,
          install_path: install_path,
        }

        # core project files
        template(File.join('Gemfile.erb'), File.join(target, 'Gemfile'), opts)
        template(File.join('gitignore.erb'), File.join(target, '.gitignore'), opts)
        template(File.join('README.md.erb'), File.join(target, 'README.md'), opts)
        template(File.join('omnibus.rb.example.erb'), File.join(target, 'omnibus.rb.example'), opts)

        # project definition
        template(File.join('project.rb.erb'), File.join(target, 'config', 'projects', "#{name}.rb"), opts)

        # example software definitions
        config_software = File.join(target, 'config', 'software')
        template(File.join('software', 'c-example.rb.erb'), File.join(config_software, 'c-example.rb'), opts)
        template(File.join('software', 'erlang-example.rb.erb'), File.join(config_software, 'erlang-example.rb'), opts)
        template(File.join('software', 'ruby-example.rb.erb'), File.join(config_software, 'ruby-example.rb'), opts)

        # Kitchen build environment
        template(File.join('.kitchen.local.yml.erb'), File.join(target, '.kitchen.local.yml'), opts)
        template(File.join('.kitchen.yml.erb'), File.join(target, '.kitchen.yml'), opts)
        template(File.join('Berksfile.erb'), File.join(target, 'Berksfile'), opts)

        # render out stub packge scripts
        %w(makeselfinst preinst prerm postinst postrm).each do |package_script|
          script_path = File.join(target, 'package-scripts', name, package_script)
          template_path = File.join('package_scripts', "#{package_script}.erb")
          # render the package script
          template(template_path, script_path, opts)
          # ensure the package script is executable
          FileUtils.chmod(0755, script_path)
        end
      end

      desc 'version', 'Display version information'
      def version
        say("Omnibus: #{Omnibus::VERSION}", :yellow)
      end

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
