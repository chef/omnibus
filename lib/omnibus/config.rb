#
# Copyright:: Copyright (c) 2012-2014 Chef Software, Inc.
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

require 'mixlib/config'
require 'omnibus/exceptions'
require 'json'

module Omnibus
  # Global configuration object for Omnibus runs.
  #
  # @todo Write a {http://yardoc.org/guides/extending-yard/writing-handlers.html
  #   Yard handler} for Mixlib::Config-style DSL methods.  I'd like
  #   the default value to show up in the docs without having to type
  #   it out twice, which I'm doing now for benefit of viewers of the Yard docs.
  class Config
    extend Mixlib::Config

    # @!group Directory Configuration Parameters

    # @!attribute [rw] cache_dir
    #   The absolute path to the directory on the virtual machine where
    #   code will be cached.
    #
    #   Defaults to `"/var/cache/omnibus/cache"`.
    #
    #   @return [String]
    default :cache_dir, '/var/cache/omnibus/cache'

    # @!attribute [rw] install_path_cache_dir
    #   The absolute path to the directory on the virtual machine where
    #   install paths will be progressively cached.
    #
    #   Defaults to `"/var/cache/omnibus/cache/install_path"`.
    #
    #   @return [String]
    default :install_path_cache_dir, '/var/cache/omnibus/cache/install_path'

    # @!attribute [rw] source_dir
    #   The absolute path to the directory on the virtual machine where
    #   source code will be downloaded.
    #
    #   Defaults to `"/var/cache/omnibus/src"`.
    #
    #   @return [String]
    default :source_dir, '/var/cache/omnibus/src'

    # @!attribute [rw] build_dir
    #   The absolute path to the directory on the virtual machine where
    #   software will be built.
    #
    #   Defaults to `"/var/cache/omnibus/build"`.
    #
    #   @return [String]
    default :build_dir, '/var/cache/omnibus/build'

    # @!attribute [rw] package_dir
    #   The absolute path to the directory on the virtual machine where
    #   packages will be constructed.
    #
    #   Defaults to `"/var/cache/omnibus/pkg"`.
    #
    #   @return [String]
    default :package_dir, '/var/cache/omnibus/pkg'

    # @!attribute [rw] package_tmp
    #   The absolute path to the directory on the virtual machine where
    #   packagers will store intermediate packaging products. Some packaging
    #   methods (notably fpm) handle this internally so not all packagers will
    #   use this setting.
    #
    #   Defaults to `"/var/cache/omnibus/pkg-tmp"`.
    #
    #   @return [String]
    default :package_tmp, '/var/cache/omnibus/pkg-tmp'

    # @!attribute [rw] project_dir
    #   The relative path of the directory containing {Omnibus::Project}
    #   DSL files.  This is relative to {#project_root}.
    #
    #   Defaults to `"config/projects"`.
    #
    #   @return [String]
    default :project_dir, 'config/projects'

    # @!attribute [rw] software_dir
    #   The relative path of the directory containing {Omnibus::Software}
    #   DSL files.  This is relative {#project_root}.
    #
    #   Defaults to `"config/software"`.
    #
    #   @return [String]
    default :software_dir, 'config/software'

    # @!attribute [rw] project_root
    #   The root directory in which to look for {Omnibus::Project} and
    #   {Omnibus::Software} DSL files.
    #
    #   Defaults to the current working directory.
    #
    #   @return [String]
    default :project_root, Dir.pwd

    # @!attribute [rw] install_dir
    #   Installation directory
    #
    #   Defaults to `"/opt/chef"`.
    #
    #   @todo This appears to be unused, and actually conflated with
    #     {Omnibus::Project#install_path}
    #
    #   @return [String]
    default :install_dir, '/opt/chef'

    # @!endgroup

    # @!group S3 Caching Configuration Parameters

    # @!attribute [rw] use_s3_caching
    #   Indicate if you wish to cache software artifacts in S3 for
    #   quicker build times.  Requires {#s3_bucket}, {#s3_access_key},
    #   and {#s3_secret_key} to be set if this is set to `true`.
    #
    #   Defaults to `false`.
    #
    #   @return [Boolean]
    default :use_s3_caching, false

    # @!attribute [rw] s3_bucket
    #   The name of the S3 bucket you want to cache software artifacts in.
    #
    #   Defaults to `nil`.  Must be set if {#use_s3_caching} is `true`.
    #
    #   @return [String, nil]
    default :s3_bucket, nil

    # @!attribute [rw] s3_access_key
    #   The S3 access key to use with S3 caching.
    #
    #   Defaults to `nil`.  Must be set if {#use_s3_caching} is `true`.
    #
    #   @return [String, nil]
    default :s3_access_key, nil

    # @!attribute [rw] s3_secret_key
    #   The S3 secret key to use with S3 caching.
    #
    #   Defaults to `nil`.  Must be set if {#use_s3_caching} is `true.`
    #
    #   @return [String, nil]
    default :s3_secret_key, nil

    # @!endgroup

    # @!group S3 Release Parameters

    # @!attribute [rw] release_s3_bucket
    #   The name of the S3 bucket you want to release artifacts to.
    #
    #   Defaults to `nil`.  Must be set to use `release package` command.
    #
    #   @return [String, nil]
    default :release_s3_bucket, nil

    # @!attribute [rw] release_s3_access_key
    #   The S3 access key to use for S3 artifact release.
    #
    #   Defaults to `nil`.  Must be set to use `release package` command.
    #
    #   @return [String, nil]
    default :release_s3_access_key, nil

    # @!attribute [rw] release_s3_secret_key
    #   The S3 secret key to use for S3 artifact release
    #
    #   Defaults to `nil`.  Must be set to use `release package` command.
    #
    #   @return [String, nil]
    default :release_s3_secret_key, nil

    # @!endgroup

    # @!group Miscellaneous Configuration Parameters

    # @!attribute [rw] override_file
    #
    #   @return [Boolean]
    default :override_file, nil

    # @!attribute [rw] software_gem
    #
    #   The gem to pull software definitions from.  This is just the name of the gem, which is used
    #   to find the path to your software definitions, and you must also specify this gem in the
    #   Gemfile of your project repo in order to include the gem in your bundle.
    #
    #   Defaults to "omnibus-software".
    #
    #   @return [String, nil]
    default :software_gem, 'omnibus-software'

    # @!attribute [rw] solaris_compiler
    #
    #   @return [String, nil]
    default :solaris_compiler, nil

    # @!endgroup

    # @!group Build Version Parameters

    # @!attribute [rw] append_timestamp
    #
    #   @return [Boolean]
    default :append_timestamp, true

    # # @!endgroup

    # @!group Build Control Parameters

    # @! attribute [rw] build_retries
    #
    #   @return [Integer, nil]
    default :build_retries, 3

    # @!group Validation Methods

    # Asserts that the Config object is in a valid state.  If invalid
    # for any reason, an exception will be thrown.
    #
    # @raise [RuntimeError]
    # @return [void]
    def self.validate
      valid_s3_config?
      # add other validation methods as needed
    end

    # @raise [InvalidS3Configuration]
    def self.valid_s3_config?
      if use_s3_caching
        unless s3_bucket
          fail InvalidS3Configuration.new(s3_bucket, s3_access_key, s3_secret_key)
        end
      end
    end

    # @!endgroup
  end # Config
end # Omnibus
