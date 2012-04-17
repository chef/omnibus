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

require 'singleton'

module Omnibus

  class Config
    include Singleton

    def self.default_values
      @default_values ||= []
    end

    def self.configurable(name, opts={})
      attr_accessor name
      default_values << [name, opts[:default]] if opts[:default]
    end

    def reset!
      self.class.default_values.each do |option, default|
        send("#{option}=", default)
      end
    end

    def initialize
      reset!
    end

    configurable :cache_dir, :default => "/var/cache/omnibus/cache"
    configurable :source_dir, :default => "/var/cache/omnibus/src"
    configurable :build_dir, :default => "/var/cache/omnibus/build"
    configurable :package_dir, :default => "/var/cache/omnibus/pkg"
    configurable :install_dir, :default => "/opt/chef"

    configurable :use_s3_caching, :default => false

    configurable :s3_bucket
    configurable :s3_access_key
    configurable :s3_secret_key
  end

  def self.config
    Config.instance
  end

  def self.configure
    yield config
  end

end

