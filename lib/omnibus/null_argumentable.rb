#
# Copyright 2014-2018 Chef Software, Inc.
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
  module NullArgumentable
    #
    # The "empty" null object.
    #
    # @return [Object]
    #
    NULL = Object.new.freeze

    #
    # Called when the module is included.
    #
    # @param [Object] base
    #
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      #
      # Check if the given object is null.
      #
      # @return [true, false]
      #
      def null?(object)
        object.equal?(NULL)
      end
    end

    # @see (NullArgumentable.null?)
    def null?(object)
      self.class.null?(object)
    end
  end
end
