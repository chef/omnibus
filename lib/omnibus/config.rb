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

require 'omnibus/exceptions'

module Omnibus

  # Global configuration object for Omnibus runs.
  class Config

    attr_reader :root, :gem_root

    # This macro is just for setting up a read/write attribute whose
    # reader has a default value.  We're doing it this way in order to
    # expose the defaults in API documentation.
    #
    # @param name [Symbol, String] the name of the attribute
    # @param type [Class, String] the type of the attribute.
    #   Currently this is ONLY used by Yard to generate proper
    #   documentation.  It is not used in the code at all.
    # @param default [Object] the default value for the attribute in
    #   the absence of being explicitly set to anything else
    #
    # @!macro [attach] configurable
    #   Defaults to `$3`
    #   @return [$2]
    def self.configurable(name, type, default)
      attr_writer name
      define_method name do
        x = self.instance_variable_get("@#{name}")
        x ||= default
      end
    end

    def initialize(root, gem_root)
      @root, @gem_root = root, gem_root
    end

    # @!group Directory Configuration Parameters

    # The absolute path to the directory on the virtual machine where
    # code will be cached.
    #
    # @!attribute [rw] cache_dir
    configurable :cache_dir, String, "/var/cache/omnibus/cache"

    # The absolute path to the directory on the virtual machine where
    # source code will be downloaded.
    #
    # @!attribute [rw] source_dir
    configurable :source_dir, String, "/var/cache/omnibus/src"

    # The absolute path to the directory on the virtual machine where
    # software will be built.
    #
    # @!attribute [rw] build_dir
    configurable :build_dir, String, "/var/cache/omnibus/build"

    # The absolute path to the directory on the virtual machine where
    # packages will be constructed.
    #
    # @!attribute [rw] package_dir
    configurable :package_dir, String, "/var/cache/omnibus/pkg"

    # The relative path of the directory containing {Omnibus::Project}
    # DSL files.  This is relative to your repository directory.
    #
    # @!attribute [rw] project_dir
    configurable :project_dir, String, "config/projects"

    # The relative path of the directory containing {Omnibus::Software}
    # DSL files.  This is relative to your repository directory.
    #
    # @!attribute [rw] software_dir
    configurable :software_dir, String, "config/software"

    # Installation directory
    #
    # @todo This appears to be unused, and actually conflated with
    #   Omnibus::Project#install_path
    # @!attribute [rw] install_dir
    configurable :install_dir, String, "/opt/chef"

    # @!endgroup

    # @!group S3 Caching Configuration Parameters

    # @!attribute [rw] use_s3_caching
    configurable :use_s3_caching, 'Boolean', false # "Boolean" isn't really a Ruby type,
                                                   # but it's just used for Yard
                                                   # documentation, so a String is fine

    # @!attribute [rw] s3_bucket
    configurable :s3_bucket, String, nil

    # @!attribute [rw] s3_access_key
    configurable :s3_access_key, String, nil

    # @!attribute [rw] s3_secret_key
    configurable :s3_secret_key, String, nil

    # @!endgroup

    # @!group Miscellaneous Configuration Parameters

    # @!attribute [rw] override_file
    configurable :override_file, String, nil

    # @!attribute [rw] solaris_compiler
    configurable :solaris_compiler, String, nil

    # @!endgroup

    # Asserts that the Config object is in a valid state.  If invalid
    # for any reason, an exception will be thrown.
    #
    # @throw [RuntimeError]
    # @return [void]
    def validate
      [:valid_s3_config?].each do |test|
        send(test)
      end
    end

    # @raise [InvalidS3Configuration]
    def valid_s3_config?
      if use_s3_caching
        unless s3_bucket && s3_access_key && s3_secret_key
          raise InvalidS3Configuration.new(s3_bucket, s3_access_key, s3_secret_key)
        end
      end
    end
  end
end
