#
# Copyright 2012-2018 Chef Software, Inc.
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
    include Enumerable

    # The list of Omnibus::Software definitions. This is populated by calling
    # #component_added during code loading. The list is expected to be sorted
    # in a valid order according to project and software dependencies, but this
    # class does not verify that condition.
    #
    # @see Omnibus.expand_software
    # @return [Array<Omnibus::Software>] the software components in optimized
    #   order.
    attr_reader :components

    def initialize(project)
      @components = []
      @project = project
    end

    # Callback method that should be called each time an Omnibus::Software
    # definition file is loaded.
    #
    # @param component [Omnibus::Software]
    # @return [void]
    def component_added(component)
      unless @components.find { |c| c.name == component.name }
        @components << component
      end
    end

    # The order in which each Software component should be built. The order is
    # based on the order of #components, optimized to move top-level
    # dependencies later in the build order to make the git caching feature
    # more effective. It is assumed that #components is already sorted in a
    # valid dependency order. The optimization works as follows:
    #
    # 1. The first component is assumed to be a preparation step that needs to
    # run first, so it is not moved.
    # 2. If a component is a top-level dependency of the project AND no other
    # software depends on it, it is shifted to last in the optimized order.
    # 3. If none of the above conditions are met, the order of that component
    # is unchanged.
    #
    # @return [Array<Omnibus::Software>] the software components in optimized
    #   order.
    def build_order
      head = []
      tail = []
      @components.each do |component|
        if head.length == 0
          head << component
        elsif @project.dependencies.include?(component.name) && @components.none? { |c| c.dependencies.include?(component.name) }
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

    def each(&block)
      @components.each(&block)
    end
  end
end
