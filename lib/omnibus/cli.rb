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

require 'thor'
require 'omnibus/version'
require 'mixlib/shellout'

module Omnibus
  class CLI < Thor

    method_option :timestamp,
      :aliases => [:t],
      :type => :boolean,
      :default => true,
      :desc => "Append timestamp information to the version identifier?  Add a timestamp for nightly releases; leave it off for release and prerelease builds"

    method_option :path,
      :aliases => [:p],
      :type => :string,
      :default => Dir.pwd,
      :desc => "Path to Omnibus project root."

    desc "build PROJECT", "Build the given Omnibus project"
    def build(project)
      if looks_like_omnibus_project?(options[:path])
        say("Building #{project}", :green)
        unless options[:timestamp]
          say("I won't append a timestamp to the version identifier.", :yellow)
        end
        # Until we have time to integrate the CLI deeply into the Omnibus codebase
        # this will have to suffice! (sadpanda)
        env = {'OMNIBUS_APPEND_TIMESTAMP' => options[:timestamp].to_s}
        shellout!("rake projects:#{project} 2>&1", :environment => env, :cwd => options[:path])
      else
        raise Thor::Error, "Given path [#{options[:path]}] does not appear to be a valid Omnibus project root."
      end
    end

    desc "version", "Display version information"
    def version
      say("Omnibus: #{Omnibus::VERSION}", :yellow)
    end

    private

    def shellout!(command, options={})
      STDOUT.sync = true
      default_options = {
        :live_stream => STDOUT,
        :timeout => 7200, # 2 hours
        :environment => {}
      }
      shellout = Mixlib::ShellOut.new(command, default_options.merge(options))
      shellout.run_command
      shellout.error!
    end

    # Forces command to exit with a 1 on any failure...so raise away.
    def self.exit_on_failure?
      true
    end

    def looks_like_omnibus_project?(path)
      File.exist?(File.join(path, "Rakefile")) &&
        Dir["#{path}/config/projects/*.rb"].any?
    end
  end
end
