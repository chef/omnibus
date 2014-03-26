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

require 'omnibus/cli/base'

module Omnibus
  module CLI
    class Build < Base
      namespace :build

      class_option :path,
                   aliases: [:p],
                   type: :string,
                   default: Dir.pwd,
                   desc: 'Path to the Omnibus project root.'

      method_option :timestamp,
                    aliases: [:t],
                    type: :boolean,
                    default: true,
                    desc: 'Append timestamp information to the version ' \
                          'identifier? Add a timestamp for build versions; ' \
                          'leave it off for release and pre-release versions'
      desc 'project PROJECT', 'Build the given Omnibus project'
      def project(project_name)
        project = load_project!(project_name)

        unless options[:timestamp]
          say("I won't append a timestamp to the version identifier.", :yellow)
        end
        say("Building #{project.name} #{project.build_version}", :green)

        project.build_me
      end

      desc 'software PROJECT SOFTWARE', 'Build the given software component'
      def software(project_name, software_name)
        project = load_project!(project_name)

        software = project.library.components.find do |s|
          s.name == software_name
        end

        say("Building #{software_name} for #{project.name} project", :green)

        software.build_me
      end
    end
  end
end
