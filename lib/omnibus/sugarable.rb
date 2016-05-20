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

require "chef/sugar/architecture"
require "chef/sugar/cloud"
require "chef/sugar/constraints"
require "chef/sugar/ip"
require "chef/sugar/platform"
require "chef/sugar/platform_family"
require "chef/sugar/ruby"
require "chef/sugar/shell"
require "chef/sugar/vagrant"

module Omnibus
  module Sugarable
    def self.extended(base)
      base.send(:extend, Chef::Sugar::DSL)
      base.send(:extend, Omnibus::Sugar)
    end

    def self.included(base)
      base.send(:include, Chef::Sugar::DSL)
      base.send(:include, Omnibus::Sugar)

      if base < Cleanroom
        # Make all the "sugars" available in the cleanroom (DSL)
        Chef::Sugar::DSL.instance_methods.each do |instance_method|
          base.send(:expose, instance_method)
        end

        # Make all the common "sugars" available in the cleanroom (DSL)
        Omnibus::Sugar.instance_methods.each do |instance_method|
          base.send(:expose, instance_method)
        end
      end
    end

    # This method is used by Chef Sugar to easily add the DSL. By mimicing
    # Chef's +node+ object, we can easily include the existing DSL into
    # Omnibus project as if it were Chef. Otherwise, we would need to rewrite
    # all the DSL methods.
    def node
      Ohai
    end
  end

  # This module is a wrapper for common Chef::Sugar-like functions that
  # are common to multiple DSLs (like project and software). The extensions
  # below will be injected into CleanRoom, and hence visible to the DSLs.
  module Sugar

    # Returns whether the Windows build target is 32-bit (x86).
    # If this returns false, the target is x64. Itanium is not supported.
    def windows_arch_i386?
      Config.windows_arch.to_sym == :x86
    end
  end
end
