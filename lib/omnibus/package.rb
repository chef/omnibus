#
# Copyright 2014-2018 Chef Software, Inc.
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

require "ffi_yajl" unless defined?(FFI_Yajl)

module Omnibus
  class Package
    include Digestable

    #
    # @return [String]
    #
    attr_reader :path

    #
    # Create a new package from the given path.
    #
    # @param [String] path
    #   the path to the package on disk
    #
    def initialize(path)
      @path = File.expand_path(path)
    end

    #
    # The shortname of this package (the basename of the file).
    #
    # @return [String]
    #
    def name
      @name ||= File.basename(path)
    end

    #
    # The MD5 checksum for this file.
    #
    # @return [String]
    #
    def md5
      @md5 ||= digest(path, :md5)
    end

    #
    # The SHA1 checksum for this file.
    #
    # @return [String]
    #
    def sha1
      @sha1 ||= digest(path, :sha1)
    end

    #
    # The SHA256 checksum for this file.
    #
    # @return [String]
    #
    def sha256
      @sha256 ||= digest(path, :sha256)
    end

    #
    # The SHA512 checksum for this file.
    #
    # @return [String]
    #
    def sha512
      @sha512 ||= digest(path, :sha512)
    end

    #
    # The actual contents of the package.
    #
    # @return [String]
    #
    def content
      @content ||= IO.read(path)
    rescue Errno::ENOENT
      raise NoPackageFile.new(path)
    end

    #
    # The parsed contents of the metadata.
    #
    # @raise [NoPackageMetadataFile] if the {#metadata} does not exist
    # @raise [FFI_Yajl::ParseError] if the JSON is not valid
    #
    # @return [Hash<Symbol, String>]
    #
    def metadata
      @metadata ||= Metadata.for_package(self)
    end

    #
    # Set the metadata for this package
    #
    # @param [Metadata] metadata
    #
    def metadata=(metadata)
      @metadata = metadata
    end

    #
    # Validate the presence of the required components for the package.
    #
    # @raise [NoPackageFile] if the package is not present
    # @raise [NoPackageMetadataFile] if the metadata file is not present
    #
    # @return [true]
    #
    def validate!
      unless File.exist?(path)
        raise NoPackageFile.new(path)
      end

      unless File.exist?(metadata.path)
        raise NoPackageMetadataFile.new(metadata.path)
      end

      true
    end
  end
end
