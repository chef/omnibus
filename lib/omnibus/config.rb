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

require "singleton"

module Omnibus
  class Config
    include Cleanroom
    include NullArgumentable
    include Singleton
    include Util

    class << self
      #
      # @param [String] filepath
      #   the path to the config definition to load from disk
      #
      # @return [Config]
      #
      def load(filepath)
        evaluate_file(instance, filepath)
      end

      #
      # @macro default
      #   @method $1(value = NULL)
      #
      # @param [Symbol] key
      #   the name of the configuration value to create
      # @param [Object] default
      #   the default value
      # @param [Proc] block
      #   a block to be called for the default value. If the block is provided,
      #   the +default+ attribute is ignored
      #
      def default(key, default = NullArgumentable::NULL, &block)
        # This is a class method, which delegates to the instance method
        define_singleton_method(key) do |value = NullArgumentable::NULL|
          instance.send(key, value)
        end

        # This is an instance method, but this is a singleton object ;)
        define_method(key) do |value = NullArgumentable::NULL|
          set_or_return(key, value, default, &block)
        end

        # All config options should be avaiable as DSL methods
        expose(key)
      end

      #
      # Check if the configuration includes the given key.
      #
      # @param [Symbol] key
      #
      # @return [true, false]
      #
      def key?(key)
        public_method_defined?(key.to_sym)
      end
      alias_method :has_key?, :key?

      #
      # Reset the current configuration values. This method will unset any
      # "stored" or memorized configuration values.
      #
      # @return [true]
      #
      def reset!
        instance.instance_variables.each do |instance_variable|
          instance.send(:remove_instance_variable, instance_variable)
        end

        true
      end
    end

    #
    # @!group Directory Configuration Parameters
    # --------------------------------------------------

    # The "base" directory where Omnibus will store it's data. Other paths are
    # dynamically computed from this value.
    #
    # - Defaults to +C:\omnibus-ruby+ on Windows
    # - Defaults to +/var/cache/omnibus+ on other platforms
    #
    # @return [String]
    default(:base_dir) do
      if Ohai["platform"] == "windows"
        "C:/omnibus-ruby"
      else
        "/var/cache/omnibus"
      end
    end

    # The absolute path to the directory on the virtual machine where
    # code will be cached.
    #
    # @return [String]
    default(:cache_dir) { File.join(base_dir, "cache") }

    # The absolute path to the directory on the virtual machine where
    # git caching will occur and software's will be progressively cached.
    #
    # @return [String]
    default(:git_cache_dir) do
      File.join(base_dir, "cache", "git_cache")
    end

    # The absolute path to the directory on the virtual machine where
    # source code will be downloaded.
    #
    # @return [String]
    default(:source_dir) { File.join(base_dir, "src") }

    # The absolute path to the directory on the virtual machine where
    # software will be built.
    #
    # @return [String]
    default(:build_dir) { File.join(base_dir, "build") }

    # The absolute path to the directory on the virtual machine where
    # packages will be constructed.
    #
    # @return [String]
    default(:package_dir) { File.join(base_dir, "pkg") }

    # @deprecated Do not use this method.
    #
    # @return [String]
    default(:package_tmp) do
      Omnibus.logger.deprecated("Config") do
        "Config.package_tmp. This value is no longer used."
      end
    end

    # The relative path of the directory containing {Omnibus::Project}
    # DSL files.  This is relative to {#project_root}.
    #
    # @return [String]
    default(:project_dir, "config/projects")

    # The relative path of the directory containing {Omnibus::Software}
    # DSL files.  This is relative {#project_root}.
    #
    # @return [String]
    default(:software_dir, "config/software")

    # The root directory in which to look for {Omnibus::Project} and
    # {Omnibus::Software} DSL files.
    #
    # @return [String]
    default(:project_root) { Dir.pwd }

    # --------------------------------------------------
    # @!endgroup
    #

    #
    # @!group DMG / PKG configuration options
    # --------------------------------------------------

    # Package OSX pkg files inside a DMG
    #
    # @return [true, false]
    default(:build_dmg) do
      Omnibus.logger.deprecated("Config") do
        "Config.build_dmg. This value is no longer part of the " \
        "config and is implied when defining a `compressor' block in the project."
      end
    end

    # The starting x,y and ending x,y positions for the created DMG window.
    #
    # @return [String]
    default(:dmg_window_bounds) do
      Omnibus.logger.deprecated("Config") do
        "Config.dmg_window_bounds. This value is no longer part of the " \
        "config and should be defined in the `compressor' block in the project."
      end
    end

    # The starting x,y position where the .pkg file should live in the DMG
    # window.
    #
    # @return [String]
    default(:dmg_pkg_position) do
      Omnibus.logger.deprecated("Config") do
        "Config.dmg_pkg_position. This value is no longer part of the " \
        "config and should be defined in the `compressor' block in the project."
      end
    end

    # Sign the pkg package.
    #
    # @return [true, false]
    default(:sign_pkg) do
      Omnibus.logger.deprecated("Config") do
        "Config.sign_pkg. This value is no longer part of the config and " \
        "should be defined in the `package' block in the project."
      end
    end

    # The identity to sign the pkg with.
    #
    # @return [String]
    default(:signing_identity) do
      Omnibus.logger.deprecated("Config") do
        "Config.signing_identity. This value is no longer part of the " \
        "config and should be defined in the `package' block in the project."
      end
    end

    # --------------------------------------------------
    # @!endgroup
    #

    #
    # @!group RPM configuration options
    # --------------------------------------------------

    # Sign the rpm package.
    #
    # @return [true, false]
    default(:sign_rpm) do
      Omnibus.logger.deprecated("Config") do
        "Config.sign_rpm. This value is no longer part of the config and " \
        "should be defined in the `package' block in the project."
      end
    end

    # The passphrase to sign the RPM with.
    #
    # @return [String]
    default(:rpm_signing_passphrase) do
      Omnibus.logger.deprecated("Config") do
        "Config.rpm_signing_passphrase. This value is no longer part of the " \
        "config and should be defined in the `package' block in the project."
      end
    end

    # --------------------------------------------------
    # @!endgroup
    #

    #
    # @!group S3 Caching Configuration Parameters
    # --------------------------------------------------

    # Indicate if you wish to cache software artifacts in S3 for
    # quicker build times.  Requires {#s3_bucket}, {#s3_access_key},
    # and {#s3_secret_key} to be set if this is set to +true+.
    #
    # @return [true, false]
    default(:use_s3_caching, false)

    # The name of the S3 bucket you want to cache software artifacts in.
    #
    # @return [String]
    default(:s3_bucket) do
      raise MissingRequiredAttribute.new(self, :s3_bucket, "'my_bucket'")
    end

    # The S3 access key to use with S3 caching.
    #
    # @return [String]
    default(:s3_access_key) do
      raise MissingRequiredAttribute.new(self, :s3_access_key, "'ABCD1234'")
    end

    # The S3 secret key to use with S3 caching.
    #
    # @return [String]
    default(:s3_secret_key) do
      raise MissingRequiredAttribute.new(self, :s3_secret_key, "'EFGH5678'")
    end

    # The region of the S3 bucket you want to cache software artifacts in.
    # Defaults to 'us-east-1'
    #
    # @return [String]
    default(:s3_region) do
      "us-east-1"
    end

    # --------------------------------------------------
    # @!endgroup
    #

    #
    # @!group Publisher
    # --------------------------------------------------

    # The number of times to try to publish an artifact
    #
    # @return [Integer]
    default(:publish_retries, 2)

    # --------------------------------------------------
    # @!endgroup
    #

    #
    # @!group Artifactory Publisher
    # --------------------------------------------------

    # The full URL where the artifactory instance is accessible.
    #
    # @return [String]
    default(:artifactory_endpoint) do
      raise MissingRequiredAttribute.new(self, :artifactory_endpoint, "'https://...'")
    end

    # The username of the artifactory user to authenticate with.
    #
    # @return [String]
    default(:artifactory_username) do
      raise MissingRequiredAttribute.new(self, :artifactory_username, "'admin'")
    end

    # The password of the artifactory user to authenticate with.
    #
    # @return [String]
    default(:artifactory_password) do
      raise MissingRequiredAttribute.new(self, :artifactory_password, "'password'")
    end

    # The base path artifacts are published to. This is usually maps to
    # the artifacts's organization. AKA `orgPath` in the Artifactory
    # world.
    #
    # @return [String]
    default(:artifactory_base_path) do
      raise MissingRequiredAttribute.new(self, :artifactory_base_path, "'com/mycompany'")
    end

    # The path on disk to an SSL pem file to sign requests with.
    #
    # @return [String, nil]
    default(:artifactory_ssl_pem_file, nil)

    # Whether to perform SSL verification when connecting to artifactory.
    #
    # @return [true, false]
    default(:artifactory_ssl_verify, true)

    # The username to use when connecting to artifactory via a proxy.
    #
    # @return [String]
    default(:artifactory_proxy_username, nil)

    # The password to use when connecting to artifactory via a proxy.
    #
    # @return [String]
    default(:artifactory_proxy_password, nil)

    # The address to use when connecting to artifactory via a proxy.
    #
    # @return [String]
    default(:artifactory_proxy_address, nil)

    # The port to use when connecting to artifactory via a proxy.
    #
    # @return [String]
    default(:artifactory_proxy_port, nil)

    # --------------------------------------------------
    # @!endgroup
    #

    #
    # @!group S3 Publisher
    # --------------------------------------------------

    # The S3 access key to use for S3 artifact release.
    #
    # @return [String]
    default(:publish_s3_access_key) do
      raise MissingRequiredAttribute.new(self, :publish_s3_access_key, "'ABCD1234'")
    end

    # The S3 secret key to use for S3 artifact release
    #
    # @return [String]
    default(:publish_s3_secret_key) do
      raise MissingRequiredAttribute.new(self, :publish_s3_secret_key, "'EFGH5678'")
    end

    # --------------------------------------------------
    # @!endgroup
    #

    #
    # @!group Miscellaneous Configuration Parameters
    # --------------------------------------------------

    # An array of local disk paths that include software definitions to load
    # from disk. The software definitions in these paths are pulled
    # **in order**, so if multiple paths have the same software definition, the
    # one that appears **first** in the list here is chosen.
    #
    # - These paths take precedence over those defined in {#software_gems}.
    # - These paths are preceeded by local project vendored softwares.
    #
    # For these paths, it is assumed that the folder structure is:
    #
    #     /PATH/config/software/*
    #
    # @return [Array<String>]
    default(:local_software_dirs) { [] }

    # The list of gems to pull software definitions from. The software
    # definitions from these gems are pulled **in order**, so if multiple gems
    # have the same software definition, the one that appears **first** in the
    # list here is chosen.
    #
    # - These paths are preceeded by those defined in {#local_software_dirs}.
    # - These paths are preceeded by local project vendored softwares.
    #
    # For these gems, it is assumed that the folder structure is:
    #
    #     /GEM_ROOT/config/software/*
    #
    # @return [Array<String>]
    default(:software_gems) do
      ["omnibus-software"]
    end

    # Solaris linker mapfile to use, if needed
    # see http://docs.oracle.com/cd/E23824_01/html/819-0690/chapter5-1.html
    # Path is relative to the 'files' directory in your omnibus project
    #
    # For example:
    #
    #     /PATH/files/my_map_file
    #
    # @return [String, nil]
    default(:solaris_linker_mapfile, "files/mapfiles/solaris")

    # Architecture to target when building on windows.  This option
    # should affect the bit-ness of Ruby and DevKit used, the platform of
    # any MSIs generated and package dlls being downloaded.
    #
    # See the windows_arch_i386? software definition dsl
    # methods.
    #
    # @return [:x86, :x64]
    default(:windows_arch) do
      if Ohai["kernel"]["machine"] == "x86_64"
        Omnibus.logger.deprecated("Config") do
          "windows_arch is defaulting to :x86. In Omnibus 5, it will " \
          "default to :x64 if the machine architecture is x86_64. " \
          "If you would like to continue building 32 bit packages, please "\
          "manually set windows_arch in your omnibus.rb file to :x86."
        end
      end
      :x86
    end

    # --------------------------------------------------
    # @!endgroup
    #

    #
    # @!group Build Parameters
    # --------------------------------------------------

    # Append the current timestamp to the version identifier.
    #
    # @return [true, false]
    default(:append_timestamp, true)

    # The number of times to retry the build before failing.
    #
    # @return [Integer]
    default(:build_retries, 0)

    # Use the incremental build caching implemented via git. This will
    # drastically improve build times, but may result in hidden and
    # unexpected bugs.
    #
    # @return [true, false]
    default(:use_git_caching, true)

    # The number of worker threads for make. If this is not set
    # explicitly in config, it will attempt to determine via Ohai in
    # the builder, and failing that will default to 3
    #
    # @return [Integer]
    default(:workers) do
      if Ohai["cpu"] && Ohai["cpu"]["total"]
        Ohai["cpu"]["total"].to_i + 1
      else
        3
      end
    end

    # Fail the build or warn when build encounters a licensing warning.
    #
    # @return [true, false]
    default(:fatal_licensing_warnings, false)

    # Fail the build or warn when build encounters a transitive dependency
    # licensing warning.
    #
    # @return [true, false]
    default(:fatal_transitive_dependency_licensing_warnings, false)

    # --------------------------------------------------
    # @!endgroup
    #

    #
    # @!group Fetcher Parameters
    # --------------------------------------------------

    # The number of seconds to wait
    #
    # @return [Integer]
    default(:fetcher_read_timeout, 60)

    # The number of retries before marking a download as failed
    #
    # @return [Integer]
    default(:fetcher_retries, 5)

    # --------------------------------------------------
    # @!endgroup
    #

    private

    #
    #
    #
    def set_or_return(key, value = NULL, default = NULL, &block)
      instance_variable = :"@#{key}"

      if null?(value)
        if instance_variable_defined?(instance_variable)
          instance_variable_get(instance_variable)
        else
          if block
            instance_eval(&block)
          else
            null?(default) ? nil : default
          end
        end
      else
        instance_variable_set(instance_variable, value)
      end
    end
  end
end
