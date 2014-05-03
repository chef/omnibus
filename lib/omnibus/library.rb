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

    # Resorts the component build order given by dependency_order to optimize
    # the build for git-cacheability. The underlying assumption is that the
    # software at the top of the stack (e.g., erchef, chef-client, etc.) is
    # likely to change often, while software at the bottom of the stack (e.g.,
    # the erlang or ruby VM) will not change often.
    #
    # Components are sorted according to the following rules:
    # 1. The first item in dependency_order is assumed to be a build setup
    # step, so it is never moved.
    # 2. If a component is not a dependency of any other component, it is moved
    # to last in the optimized order.
    # 3. The order is not changed otherwise.
    def build_order
      optimized_order = dependency_order
      @project.dependencies.each do |component_name|
        component = component_by_name(component_name)
        # Assume that the very first dependency is something like the
        # "preparation" software that *needs* to be first.
        next if optimized_order.index(component) == 0

        # If nothing else depends on this, we are free to move it to last in
        # the build order.
        if not_a_transitive_dep?(component)
          optimized_order.delete(component)
          optimized_order << component
        end
      end
      optimized_order
    end

    # A depth-first sort of all project dependencies. The sort is
    # deterministic, uses user-supplied dependency order to break ties.
    def dependency_order
      order = []
      seen_items = {}
      @project.dependencies.each do |component_name|
        component = component_by_name(component_name)
        raise MissingProjectDependency.new(component_name, Omnibus.software_dirs) if component.nil?
        add_deps_to(order, component, seen_items)
      end
      order
    end

    def component_by_name(name)
      @components.find { |c| c.name.to_s == name.to_s }
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

    private

    def not_a_transitive_dep?(component)
      @components.none? do |c|
        c.dependencies.map(&:to_s).include?(component.name.to_s)
      end
    end

    def add_deps_to(order, component, seen_items)
      return if seen_items.key?(component)
      seen_items[component] = true
      component.dependencies.each do |dependency|
        dependency_component = component_by_name(dependency)
        raise MissingSoftwareDependency.new(dependency, Omnibus.software_dirs) if dependency_component.nil?
        add_deps_to(order, dependency_component, seen_items)
      end
      order << component
    end
  end
end
