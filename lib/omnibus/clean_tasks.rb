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
  module CleanTasks
    extend Rake::DSL

    # TODO: at some point we may want more control over what exactly
    # it is that we clean up:
    #
    # * rake clean:cache
    # * rake clean:build
    # * rake clean:package
    # * etc...
    #
    def self.define!
      require 'rake/clean'

      ::CLEAN.include("#{config.source_dir}/**/*",
                      "#{config.build_dir}/**/*")

      ::CLOBBER.include("#{config.install_dir}/**/*",
                        "#{config.cache_dir}/**/*")
    end

    def self.config
      Omnibus.config
    end
  end
end
