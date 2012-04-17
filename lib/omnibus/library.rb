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

module Omnibus
  #
  # Used to generate the manifest of all software components with versions
  class Library

    def initialize
      @projects = []
      @components = []
    end

    def component_added(component)
      @components << component
    end

    def version_map(project)
      @components.select {|c| c.project == project}.inject({}) {|map, component|
        map[component.name] = component.version; map
      }
    end

    def select(*args, &block)
      @components.select(*args, &block)
    end


  end

  def self.library
    @library ||= Library.new
  end

  def self.component_added(*args)
    library.component_added(*args)
  end

end

