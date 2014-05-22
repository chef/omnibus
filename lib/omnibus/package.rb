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

module Omnibus
  class Package
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
    # @raise [NoPackageMetadataFile] if the {metadata_path} does not exist
    # @raise [JSON::ParserError] if the JSON is not valid
    #
    # @return [Hash<Symbol, String>]
    #
    def metadata
      @metadata ||= JSON.parse(raw_metadata, symbolize_names: true)
    end

    #
    # The raw file contents of the metadata.
    #
    # @return [String]
    #
    def raw_metadata
      @raw_metadata ||= IO.read(metadata_path)
    rescue Errno::ENOENT
      raise NoPackageMetadataFile.new(path)
    end

    #
    # The path to the metadata JSON for this package.
    #
    # @return [String]
    #
    def metadata_path
      @metadata_path ||= "#{path}.metadata.json"
    end

    #
    # The shortname of the metadata for this package (the basename of the file).
    #
    # @return [String]
    #
    def metadata_name
      @metadata_name ||= File.basename(metadata_path)
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

      unless File.exist?(metadata_path)
        raise NoPackageMetadataFile.new(metadata_path)
      end

      true
    end
  end
end
