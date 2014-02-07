#
# Copyright:: Copyright (c) 2014 Opscode, Inc.
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

require 'rake'

module Omnibus
  class SoftwareDefinition
    include Rake::DSL

    NULL_ARG = Object.new

    attr_reader :name
    attr_reader :version
    attr_reader :filename

    def self.load(filename)
      new(IO.read(filename), filename)
    end

    def initialize(io, filename)
      @name = nil
      @version = nil
      @filename = filename

      instance_eval(io, filename, 0)
    end

    def name(val=NULL_ARG)
      @name = val unless val.equal?(NULL_ARG)
      @name
    end

    def version(val=NULL_ARG)
      @given_version = val unless val.equal?(NULL_ARG)
      @override_version || @given_version
    end

    def placeholder_dsl_method(var1=nil, var2=nil, var3=nil)
      # This is a placeholder method that does nothing.
    end

    # Define the methods of Omnibus::Software so that we can load a software as
    # a SoftwareDefinition
    dsl_methods = Omnibus::Software.instance_methods - Object.instance_methods - [:name, :version]
    dsl_methods.each do |dsl_method|
      define_method dsl_method, instance_method(:placeholder_dsl_method)
    end
  end
end
