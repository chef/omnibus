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

require 'chef/sugar/architecture'
require 'chef/sugar/cloud'
# NOTE: We cannot include the constraints library because of the conflicting
# +version+ attribute would screw things up. You can still use the
# +Chef::Sugar::Constraint.version('1.2.3') for comparing versions.
#
# require 'chef/sugar/constraints'
require 'chef/sugar/ip'
require 'chef/sugar/platform'
require 'chef/sugar/platform_family'
require 'chef/sugar/ruby'
require 'chef/sugar/shell'
require 'chef/sugar/vagrant'

require 'omnibus/project'

module Omnibus
  class Project
    private

    # This method is used by Chef Sugar to easily add the DSL. By mimicing
    # Chef's +node+ object, we can easily include the existing DSL into
    # Omnibus project as if it were Chef. Otherwise, we would need to rewrite
    # all the DSL methods.
    def node
      OHAI
    end
  end
end

# Include everything in Omnibus
Omnibus::Project.send(:include, Chef::Sugar::DSL)
Omnibus::Software.send(:include, Chef::Sugar::DSL)
