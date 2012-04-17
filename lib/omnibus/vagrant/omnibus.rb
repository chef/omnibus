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

require 'omnibus/vagrant/config'
require 'omnibus/vagrant/omnibus_build'

module Omnibus
module Vagrant
class Omnibus < ::Vagrant::Command::Base

  def initialize(argv, env)
    super

    @main_args, @sub_command, @sub_args = split_main_and_subcommand(argv)

    @subcommands = ::Vagrant::Registry.new
    @subcommands.register(:build) { OmnibusBuild }
  end

  def execute
    # validate the omnibus config first thing
    # TODO: validate that we have the omnibus path configured

    if @main_args.include?("-h") || @main_args.include?("--help")
      # Print the help for all the omni commands.
      return help
    end

    # If we reached this far then we must have a subcommand. If not,
    # then we also just print the help and exit.
    command_class = @subcommands.get(@sub_command.to_sym) if @sub_command
    return help if !command_class || !@sub_command
    @logger.debug("Invoking command class: #{command_class} #{@sub_args.inspect}")

    # Initialize and execute the command class
    command_class.new(@sub_args, @env).execute
  end

  def help
    opts = OptionParser.new do |opts|
      opts.banner = "Usage: vagrant omnibus <command> [<args>]"
      opts.separator ""
      opts.separator "Available subcommands:"

      # Add the available subcommands as separators in order to print them
      # out as well.
      keys = []
      @subcommands.each { |key, value| keys << key.to_s }

      keys.sort.each do |key|
        opts.separator "     #{key}"
      end

      opts.separator ""
      opts.separator "For help on any individual command run `vagrant omnibus COMMAND -h`"
    end

    @env.ui.info(opts.help, :prefix => false)
  end

end # Omnibus
end # Vagrant
end # Omnibus

Vagrant.config_keys.register(:omnibus) { Omnibus::Vagrant::Config }
Vagrant.commands.register(:omnibus) { Omnibus::Vagrant::Omnibus }
