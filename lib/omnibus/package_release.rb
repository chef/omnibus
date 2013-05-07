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

# internal
require 'omnibus/exceptions'

# stdlib
require 'json'

# external
require 'uber-s3'

module Omnibus
  class PackageRelease

    attr_reader :package_path
    attr_reader :access_policy

    # @param package_path [String] file system path to the package artifact
    # @option opts [:private, :public_read] :access specifies access control on
    #   uploaded files
    # @yield callback triggered by successful upload. Allows users of this
    #   class to add UI feedback.
    # @yieldparam s3_object_key [String] the S3 key of the uploaded object.
    def initialize(package_path, opts={:access=>:private}, &block)
      @package_path = package_path
      @metadata = nil
      @s3_client = nil

      @after_upload = if block_given?
        block
      else
        lambda { |item_key| nil }
      end

      # sets @access_policy
      handle_opts(opts)
    end

    # Primary API for this class. Validates S3 configuration and package files,
    # then runs the upload.
    # @return [void]
    # @raise [NoPackageFile, NoPackageMetadataFile] when the package or
    #   associated metadata file do not exist.
    # @raise [InvalidS3ReleaseConfiguration] when the Omnibus configuration is
    #   missing required settings.
    # @raise Also may raise errors from uber-s3 or net/http.
    def release
      validate_config!
      validate_package!
      s3_client.store(metadata_key, metadata_json, :access => access_policy)
      uploaded(metadata_key)
      s3_client.store(package_key, package_content, :access => access_policy, :content_md5 => md5)
      uploaded(package_key)
    end

    def uploaded(key)
      @after_upload.call(key)
    end

    def package_key
      File.join(platform_path, File.basename(package_path))
    end

    def metadata_key
      File.join(platform_path, File.basename(package_metadata_path))
    end

    def platform_path
      File.join(metadata["platform"], metadata["platform_version"], metadata["arch"])
    end

    def md5
      metadata["md5"]
    end

    def metadata
      @metadata ||= JSON.parse(metadata_json)
    end

    def metadata_json
      IO.read(package_metadata_path)
    end

    def package_content
      IO.read(package_path)
    end

    def package_metadata_path
      "#{package_path}.metadata.json"
    end

    def validate_package!
      if !File.exist?(package_path)
        raise NoPackageFile.new(package_path)
      elsif !File.exist?(package_metadata_path)
        raise NoPackageMetadataFile.new(package_metadata_path)
      else
        true
      end
    end

    def validate_config!
      if s3_access_key && s3_secret_key && s3_bucket
        true
      else
        err = InvalidS3ReleaseConfiguration.new(s3_bucket, s3_access_key, s3_secret_key)
        raise err
      end
    end

    def s3_client
      @s3_client ||= UberS3.new(
        :access_key => s3_access_key,
        :secret_access_key => s3_secret_key,
        :bucket => s3_bucket,
        :adaper => :net_http
      )
    end

    def s3_access_key
      config[:release_s3_access_key]
    end

    def s3_secret_key
      config[:release_s3_secret_key]
    end

    def s3_bucket
      config[:release_s3_bucket]
    end

    def config
      Omnibus.config
    end

    def handle_opts(opts)
      access_policy = opts[:access]
      if access_policy.nil?
        raise ArgumentError, "options to #{self.class} must specify `:access' (given: #{opts.inspect})"
      elsif not [:private, :public_read].include?(access_policy)
        raise ArgumentError, "option `:access' must be one of `[:private, :public_read]' (given: #{access_policy.inspect})"
      else
        @access_policy = access_policy
      end
    end

  end
end
