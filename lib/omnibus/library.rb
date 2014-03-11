#
# Copyright:: Copyright (c) 2012-2014 Chef Software, Inc.
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

module Omnibus
  #
  # Used to generate the manifest of all software components with versions
  class Library
    attr_reader :components

    def initialize(project)
      @components = []
      @project = project
    end

    def component_added(component)
      unless @components.find { |c| c.name == component.name }
        @components << component
      end
    end

    def build_order
      head = []
      tail = []
      @components.each do |component|
        if head.length == 0
          head << component
        elsif @project.dependencies.include?(component.name)
          tail << component
        else
          head << component
        end
      end
      [head, tail].flatten
    end

    def version_map
      @components.reduce({}) do |map, component|
        map[component.name] = if component.default_version
                                {
                                  version: component.version,
                                  default_version: component.default_version,
                                  overridden: component.overridden?,
                                  version_guid: component.version_guid,
                                }
                              else
                                ## Components without a version are
                                ## pieces of the omnibus project
                                ## itself, and so don't really fit
                                ## with the concept of overrides
                                v = { version: @project.build_version }
                                if @project.build_version.respond_to?(:git_sha)
                                  v[:version_guid] = "git:#{@project.build_version.git_sha}"
                                end
                                v
                              end
        map
      end
    end

    def select(*args, &block)
      @components.select(*args, &block)
    end
  end
end
