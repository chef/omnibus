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

module Omnibus
  module Cleanroom
    #
    # Callback for when this module is included.
    #
    # @param [Class] base
    #
    def self.included(base)
      base.send(:extend,  ClassMethods)
      base.send(:include, InstanceMethods)
    end

    #
    # Class methods
    #
    module ClassMethods
      #
      # Evaluate the file in the context of the cleanroom.
      #
      # @param [Class] instance
      #   the instance of the class to evaluate against
      # @param [String] filepath
      #   the path of the file to evaluate
      #
      def evaluate_file(instance, filepath)
        absolute_path = File.expand_path(filepath)
        file_contents = IO.read(absolute_path)
        evaluate(instance, file_contents, absolute_path, 1)
      end

      #
      # Evaluate the string or block in the context of the cleanroom.
      #
      # @param [Class] instance
      #   the instance of the class to evaluate against
      # @param [Array<String>] args
      #   the args to +instance_eval+
      # @param [Proc] block
      #   the block to +instance_eval+
      #
      def evaluate(instance, *args, &block)
        cleanroom.new(instance).instance_eval(*args, &block)
      end

      #
      # Expose the given method to the DSL.
      #
      # @param [Symbol] name
      #
      def expose(name)
        unless public_method_defined?(name)
          raise NameError, "undefined method `#{name}' for class `#{self.name}'"
        end

        exposed_methods[name] = true
      end

      #
      # The list of exposed methods.
      #
      # @return [Hash]
      #
      def exposed_methods
        @exposed_methods ||= {}
      end

      private

      #
      # The cleanroom instance for this class. This method is intentionally
      # NOT cached!
      #
      # @return [Class]
      #
      def cleanroom
        exposed = exposed_methods.keys
        parent = self.name

        Class.new do
          define_method(:initialize) do |instance|
            @instance = instance
          end

          exposed.each do |exposed_method|
            define_method(exposed_method) do |*args, &block|
              @instance.send(exposed_method, *args, &block)
            end
          end

          define_method(:inspect) do
            "#<#{parent} (Cleanroom)>"
          end
          alias_method :to_s, :inspect
        end
      end
    end

    #
    # Instance Mehtods
    #
    module InstanceMethods
      #
      # Evaluate the file against the current instance.
      #
      # @param (see Cleanroom.evaluate_file)
      # @return [self]
      #
      def evaluate_file(filepath)
        self.class.evaluate_file(self, filepath)
        self
      end

      #
      # Evaluate the contents against the current instance.
      #
      # @param (see Cleanroom.evaluate_file)
      # @return [self]
      #
      def evaluate(*args, &block)
        self.class.evaluate(self, *args, &block)
        self
      end
    end
  end
end
