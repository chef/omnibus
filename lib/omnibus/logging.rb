#
# Copyright 2013-2014 Chef Software, Inc.
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
  module Logging
    def self.included(base)
      base.send(:include, Methods)
      base.send(:extend,  Methods)
    end

    module Methods
      #
      # A helpful DSL method for logging an action.
      #
      # @return [Logger]
      #
      def log
        Omnibus.log
      end
    end
  end
end
