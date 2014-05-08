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
  class CLITest < Thor
    map ['-v', '--version'] => 'version'

    class_option :config,
      desc: 'Path to the Omnibus config file',
      aliases: ['-c'],
      type: :string,
      lazy_default: File.join(Dir.pwd, Omnibus::DEFAULT_CONFIG_FILENAME)

    #
    # Initialize a new Omnibus project.
    #
    #   $ omnibus new PATH
    #
    register(Generator, 'new', 'new PATH', 'Initialize a new Omnibus project',
      Generator.class_options)

    #
    # Clean the Omnibus project.
    #
    #   $ omnibus clean chefdk
    #
    register(Cleaner, 'clean', 'clean PROJECT', 'Clean the Omnibus project')
    CLI.tasks['clean'].options = Cleaner.class_options

    #
    # Display version information.
    #
    #   $ omnibus version
    #
    desc 'version', 'Display version information', hide: true
    def version
      say "Omnibus v#{Omnibus::VERSION}"
    end

    private

    #
    #
    #
    def load_project!(name)
      project = Omnibus.project(name)

      unless project
        error =  "I could not find an Omnibus project named '#{name}'. "
        error << "Valid project names are:"
        Omnibus.project_names.sort.each do |project_name|
          error << "  * #{project_name}"
        end
        fail Omnibus::CLI::Error, error
      end

      project
    end
  end
end



# require 'omnibus/cli/application'
# require 'omnibus/cli/base'
# require 'omnibus/cli/build'

module Omnibus
  module CLI
    class Error < StandardError
      attr_reader :original

      def initialize(msg, original = nil)
        super(msg)
        @original = original
      end
    end
  end
end
