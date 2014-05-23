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

require 'json'

module Omnibus
  class Package
    class Metadata
      class << self
        #
        # Generate a +metadata.json+ from the given package and data hash.
        #
        # @param [Package] package
        #   the package for this metadata
        # @param [Hash] data
        #   the hash of attributes to set in the metadata
        #
        # @return [String]
        #   the path where the metadata was saved on disk
        #
        def generate(package, data = {})
          data = {
            basename: package.name,
            md5:      package.md5,
            sha256:   package.sha256,
            sha512:   package.sha512,
          }.merge(data)

          instance = new(package, data)
          instance.save
          instance.path
        end

        #
        # Load the metadata from disk.
        #
        # @param [Package] package
        #   the package for this metadata
        #
        # @return [Metadata]
        #
        def for_package(package)
          data = File.read(path_for(package))
          hash = JSON.parse(data, symbolize_names: true)
          new(package, hash)
        rescue Errno::ENOENT
          raise NoPackageMetadataFile.new(package.path)
        end

        #
        # The metadata path that corresponds to the package.
        #
        # @param [Package] package
        #   the package for this metadata
        #
        # @return [String]
        #
        def path_for(package)
          "#{package.path}.metadata.json"
        end
      end

      #
      # Create a new metadata object for the given package and hash data.
      #
      # @param [Package] package
      #   the package for this metadata
      # @param [Hash] data
      #   the hash of attributes to set in the metadata
      #
      def initialize(package, data = {})
        @package = package
        @data    = data.dup.freeze
      end

      #
      # Helper for accessing the information inside the metadata hash.
      #
      # @return [Object]
      #
      def [](key)
        @data[key]
      end

      #
      # The name of this metadata file.
      #
      # @return [String]
      #
      def name
        @name ||= File.basename(path)
      end

      #
      # @see (Metadata.path_for)
      #
      def path
        @path ||= self.class.path_for(@package)
      end

      #
      # Save the file to disk.
      #
      # @return [true]
      #
      def save
        File.open(path, 'w+')  do |f|
          f.write(to_json)
        end

        true
      end

      #
      # The JSON representation of this metadata.
      #
      # @return [String]
      #
      def to_json
        JSON.pretty_generate(@data)
      end
    end

    include Digestable

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
    # @raise [NoPackageMetadataFile] if the {metadata} does not exist
    # @raise [JSON::ParserError] if the JSON is not valid
    #
    # @return [Hash<Symbol, String>]
    #
    def metadata
      @metadata ||= Metadata.for_package(self)
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
