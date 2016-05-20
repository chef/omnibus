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
      base.send(:include, InstanceMethods)
      base.send(:extend,  ClassMethods)
    end

    module ClassMethods
      private

      #
      # A helpful DSL method for logging an action.
      #
      # @return [Logger]
      #
      def log
        Omnibus.logger
      end

      #
      # The key to log with.
      #
      # @return [String]
      #
      def log_key
        @log_key ||= (name || "(Anonymous)").split("::")[1..-1].join("::")
      end
    end

    module InstanceMethods
      private

      # @see (ClassMethods#log)
      def log
        self.class.send(:log)
      end

      # @see (ClassMethods#log_key)
      def log_key
        self.class.send(:log_key)
      end
    end
  end
end
