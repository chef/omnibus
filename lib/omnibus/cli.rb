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

require 'thor'
require 'omnibus'

module Omnibus
  class CLI < Command::Base
    # This is the main entry point for the CLI. It exposes the method
    # {#execute!} to start the CLI.
    #
    # @note the arity of {#initialize} and {#execute!} are extremely important
    # for testing purposes. It is a requirement to perform in-process testing
    # with Aruba. In process testing is much faster than spawning a new Ruby
    # process for each test.
    class Runner
      include Logging

      def initialize(argv, stdin = STDIN, stdout = STDOUT, stderr = STDERR, kernel = Kernel)
        @argv, @stdin, @stdout, @stderr, @kernel = argv, stdin, stdout, stderr, kernel
      end

      def execute!
        $stdin  = @stdin
        $stdout = @stdout
        $stderr = @stderr

        Omnibus::CLI.start(@argv)
        @kernel.exit(0)
      rescue Omnibus::Error => e
        error = Omnibus.ui.set_color(e.message, :red)
        backtrace = Omnibus.ui.set_color("\n" + e.backtrace.join("\n  "), :red)
        Omnibus.ui.error(error)
        Omnibus.ui.error(backtrace)

        if e.respond_to?(:status_code)
          @kernel.exit(e.status_code)
        else
          @kernel.exit(1)
        end
      end
    end

    map %w(-v --version) => 'version'

    #
    # Build an Omnibus project or software definition.
    #
    #   $ omnibus build chefdk
    #
    method_option :output_manifest,
      desc: "Create version-manifest.json in current directory at the end of the build",
      type: :boolean,
      default: false
    method_option :use_manifest,
      desc: "Use the given manifest when downloading software sources.",
      type: :string,
      default: nil
    desc 'build PROJECT', 'Build the given Omnibus project'
    def build(name)
      manifest = if @options[:use_manifest]
                   Omnibus::Manifest.from_file(@options[:use_manifest])
                 else
                   nil
                 end

      project = Project.load(name, manifest)
      say("Building #{project.name} #{project.build_version}...")
      project.download
      project.build

      if @options[:output_manifest]
        File.open('version-manifest.json', 'w') do |f|
          f.write(JSON.pretty_generate(project.built_manifest.to_hash))
        end
      end
    end

    #
    # Perform cache management functions.
    #
    #   $ omnibus cache list
    #
    register(Command::Cache, 'cache', 'cache [COMMAND]', 'Manage the cache')
    CLI.tasks['cache'].options = Command::Cache.class_options

    #
    # Clean the Omnibus project.
    #
    #   $ omnibus clean chefdk
    #
    register(Cleaner, 'clean', 'clean PROJECT', 'Clean the Omnibus project')
    CLI.tasks['clean'].options = Cleaner.class_options

    #
    # Initialize a new Omnibus project.
    #
    #   $ omnibus new NAME
    #
    register(Generator, 'new', 'new NAME', 'Initialize a new Omnibus project')
    CLI.tasks['new'].options = Generator.class_options

    #
    # List the Omnibus projects available from "here".
    #
    #   $ omnibus list
    #
    desc 'list', 'List the Omnibus projects'
    def list
      if Omnibus.projects.empty?
        say('There are no Omnibus projects!')
      else
        say('Omnibus projects:')
        Omnibus.projects.sort.each do |project|
          say("  * #{project.name} (#{project.build_version})")
        end
      end
    end

    #
    # Publish Omnibus package(s) to a backend.
    #
    #   $ omnibus publish s3 pkg/*chef*
    #
    register(Command::Publish, 'publish', 'publish [COMMAND]', 'Publish Omnibus packages to a backend')
    CLI.tasks['publish'].options = Command::Publish.class_options

    #
    # Display version information.
    #
    #   $ omnibus version
    #
    desc 'version', 'Display version information', hide: true
    def version
      say("Omnibus v#{Omnibus::VERSION}")
    end
  end
end
