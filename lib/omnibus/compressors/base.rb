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

require 'fileutils'

module Omnibus
  class Compressor::Base < Packager::Base
    # The {Project} instance that we are compressing
    attr_reader :project

    # The {Packager::Base} instance that produced the compressed file
    attr_reader :packager

    #
    # Create a new compressor object from the given packager.
    #
    # @param [~Packager::Base] packager
    #
    def initialize(project)
      @project  = project
      @packager = project.packager
    end
  end
end
