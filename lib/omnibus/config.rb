#
# Copyright 2012-2014 Chef Software, Inc.
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

module Omnibus
  # Global configuration object for Omnibus runs.
  #
  # @todo Write a {http://yardoc.org/guides/extending-yard/writing-handlers.html
  #   Yard handler} for Mixlib::Config-style DSL methods.  I'd like
  #   the default value to show up in the docs without having to type
  #   it out twice, which I'm doing now for benefit of viewers of the Yard docs.
  class Config
    extend Mixlib::Config
    extend Util

    # Use strict mode
    config_strict_mode true

    # @!group Directory Configuration Parameters

    # @!attribute [rw] base_dir
    #   The "base" directory where Omnibus will store it's data. Other paths are
    #   dynamically constructed from this value.
    #
    #   Defaults to `"C:\omnibus-ruby"` on Windows
    #   Defaults to `"/var/cache/omnibus"` on other platforms
    #
    #   @return [String]
    default(:base_dir) do
      if Ohai['platform'] == 'windows'
        'C:\\omnibus-ruby'
      else
        '/var/cache/omnibus'
      end
    end

    # @!attribute [rw] cache_dir
    #   The absolute path to the directory on the virtual machine where
    #   code will be cached.
    #
    #   Defaults to `"/var/cache/omnibus/cache"`.
    #
    #   @return [String]
    default(:cache_dir) { windows_safe_path(base_dir, 'cache') }

    # @!attribute [rw] git_cache_dir
    #   The absolute path to the directory on the virtual machine where
    #   git caching will occur and software's will be progressively cached.
    #
    #   Defaults to `"/var/cache/omnibus/cache/git_cache"`.
    #
    #   @return [String]
    default(:git_cache_dir) { windows_safe_path(base_dir, 'cache', 'git_cache') }

    # @!attribute [rw] source_dir
    #   The absolute path to the directory on the virtual machine where
    #   source code will be downloaded.
    #
    #   Defaults to `"/var/cache/omnibus/src"`.
    #
    #   @return [String]
    default(:source_dir) { windows_safe_path(base_dir, 'src') }

    # @!attribute [rw] build_dir
    #   The absolute path to the directory on the virtual machine where
    #   software will be built.
    #
    #   Defaults to `"/var/cache/omnibus/build"`.
    #
    #   @return [String]
    default(:build_dir) { windows_safe_path(base_dir, 'build') }

    # @!attribute [rw] package_dir
    #   The absolute path to the directory on the virtual machine where
    #   packages will be constructed.
    #
    #   Defaults to `"/var/cache/omnibus/pkg"`.
    #
    #   @return [String]
    default(:package_dir) { windows_safe_path(base_dir, 'pkg') }

    # @!attribute [rw] package_tmp
    #   The absolute path to the directory on the virtual machine where
    #   packagers will store intermediate packaging products. Some packaging
    #   methods (notably fpm) handle this internally so not all packagers will
    #   use this setting.
    #
    #   Defaults to `"/var/cache/omnibus/pkg-tmp"`.
    #
    #   @return [String]
    default(:package_tmp) { windows_safe_path(base_dir, 'pkg-tmp') }

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
    default(:project_root) { Dir.pwd }

    # @!endgroup

    # @!group DMG / PKG configuration options

    # @!attribute [rw] build_dmg
    #   Package OSX pkg files inside a DMG
    #
    # @return [Boolean]
    default :build_dmg, true

    # @!attribute [rw] dmg_window_bounds
    #   Indicate the starting x,y and ending x,y positions for the created DMG
    #   window.
    #
    # @return [String]
    default :dmg_window_bounds, '100, 100, 750, 600'

    # @!attribute [rw] dmg_pkg_position
    #   Indicate the starting x,y position where the .pkg file should live in
    #   the DMG window.
    #
    # @return [String]
    default :dmg_pkg_position, '535, 50'

    # @!attribute [rw] sign_pkg
    #   Sign the pkg package.
    #
    #   Default is false.
    #
    #   @return [Boolean]
    default :sign_pkg, false

    # @!attribute [rw] signing_identity
    #   The identity to sign the pkg with.
    #
    #   Default is nil. Required if sign_pkg is set.
    #
    #   @return [String]
    default :signing_identity, nil

    # @!endgroup

    #
    # @!group S3 Caching Configuration Parameters
    # --------------------------------------------------

    # @!attribute [rw] use_s3_caching
    #   Indicate if you wish to cache software artifacts in S3 for
    #   quicker build times.  Requires {#s3_bucket}, {#s3_access_key},
    #   and {#s3_secret_key} to be set if this is set to `true`.
    #   @return [Boolean]
    default(:use_s3_caching, false)

    # @!attribute [rw] s3_bucket
    #   The name of the S3 bucket you want to cache software artifacts in.
    #   @return [String]
    default(:s3_bucket) do
      raise MissingConfigOption.new(:s3_bucket, "'my_bucket'")
    end

    # @!attribute [rw] s3_access_key
    #   The S3 access key to use with S3 caching.
    #   @return [String]
    default(:s3_access_key) do
      raise MissingConfigOption.new(:s3_access_key, "'ABCD1234'")
    end

    # @!attribute [rw] s3_secret_key
    #   The S3 secret key to use with S3 caching.
    #   @return [String]
    default(:s3_secret_key) do
      raise MissingConfigOption.new(:s3_secret_key, "'EFGH5678'")
    end

    # --------------------------------------------------
    # @!endgroup
    #

    #
    # @!group Artifactory Publisher
    # --------------------------------------------------

    # @!attribute [rw] artifactory_endpoint
    #   The full URL where the artifactory instance is accessible.
    #   @return [String]
    default(:artifactory_endpoint) do
      raise MissingConfigOption.new(:artifactory_endpoint, "'https://...'")
    end

    # @!attribute [rw] artifactory_username
    #   The username of the artifactory user to authenticate with.
    #   @return [String]
    default(:artifactory_username) do
      raise MissingConfigOption.new(:artifactory_username, "'admin'")
    end

    # @!attribute [rw] artifactory_password
    #   The password of the artifactory user to authenticate with.
    #   @return [String]
    default(:artifactory_password) do
      raise MissingConfigOption.new(:artifactory_password, "'password'")
    end

    # @!attribute [rw] artifactory_ssl_pem_file
    #   The path on disk to an SSL pem file to sign requests with.
    #   @return [String, nil]
    default(:artifactory_ssl_pem_file, nil)

    # @!attribute [rw] artifactory_ssl_verify
    #   Whether to perform SSL verification when connecting to artifactory.
    #   @return [true, false]
    default(:artifactory_ssl_verify, true)

    # @!attribute [rw] artifactory_proxy_username
    #   The username to use when connecting to artifactory via a proxy.
    #   @return [String]
    default(:artifactory_proxy_username, nil)

    # @!attribute [rw] artifactory_proxy_password
    #   The password to use when connecting to artifactory via a proxy.
    #   @return [String]
    default(:artifactory_proxy_password, nil)

    # @!attribute [rw] artifactory_proxy_address
    #   The address to use when connecting to artifactory via a proxy.
    #   @return [String]
    default(:artifactory_proxy_address, nil)

    # @!attribute [rw] artifactory_proxy_port
    #   The port to use when connecting to artifactory via a proxy.
    #   @return [String]
    default(:artifactory_proxy_port, nil)

    # --------------------------------------------------
    # @!endgroup
    #

    #
    # @!group S3 Publisher
    # --------------------------------------------------

    # @!attribute [rw] publish_s3_access_key
    #   The S3 access key to use for S3 artifact release.
    #   @return [String]
    default(:publish_s3_access_key) do
      raise MissingConfigOption.new(:publish_s3_access_key, "'ABCD1234'")
    end

    # @!attribute [rw] publish_s3_secret_key
    #   The S3 secret key to use for S3 artifact release
    #   @return [String]
    default(:publish_s3_secret_key) do
      raise MissingConfigOption.new(:publish_s3_secret_key, "'EFGH5678'")
    end

    # --------------------------------------------------
    # @!endgroup
    #

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
    #   Append the current timestamp to the version identifier.
    #
    #   @return [Boolean]
    default :append_timestamp, true

    # # @!endgroup

    # @!group Build Control Parameters

    # @! attribute [rw] build_retries
    #   The number of times to retry the build before failing.
    #
    #   @return [Integer, nil]
    default :build_retries, 3
  end
end
