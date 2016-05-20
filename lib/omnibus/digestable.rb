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

require "openssl"
require "pathname"
require "omnibus/logging"

module Omnibus
  module Digestable

    def self.included(other)
      other.send(:include, Logging)
    end

    #
    # Calculate the digest of the file at the given path. Files are read in
    # binary chunks to prevent Ruby from exploding.
    #
    # @param [String] path
    #   the path of the file to digest
    # @param [Symbol] type
    #   the type of digest to use
    #
    # @return [String]
    #   the hexdigest of the file at the path
    #
    def digest(path, type = :md5)
      digest = digest_from_type(type)

      update_with_file_contents(digest, path)
      digest.hexdigest
    end

    #
    # Calculate the digest of a directory at the given path. Each file in the
    # directory is read in binary chunks to prevent excess memory usage.
    # Filesystem entries of all types are included in the digest, including
    # directories, links, and sockets. The contents of non-file entries are
    # represented as:
    #
    #   $type $path
    #
    # while the contents of regular files are represented as:
    #
    #   file $path
    #
    # and then appended by the binary contents of the file/
    #
    # @param [String] path
    #   the path of the directory to digest
    # @param [Symbol] type
    #   the type of digest to use
    # @param [Hash] options
    #   options to pass through to the FileSyncer when scanning for files
    #
    # @return [String]
    #   the hexdigest of the directory
    #
    def digest_directory(path, type = :md5, options = {})
      digest = digest_from_type(type)
      log.info(log_key) { "Digesting #{path} with #{type}" }
      FileSyncer.all_files_under(path, options).each do |filename|
        # Calculate the filename relative to the given path. Since directories
        # are SHAed according to their filepath, two difference directories on
        # disk would have different SHAs even if they had the same content.
        relative = Pathname.new(filename).relative_path_from(Pathname.new(path))

        case ftype = File.ftype(filename)
        when "file"
          update_with_string(digest, "#{ftype} #{relative}")
          update_with_file_contents(digest, filename)
        else
          update_with_string(digest, "#{ftype} #{relative}")
        end
      end

      digest.hexdigest
    end

    private

    #
    # Create a new instance of the {Digest} class that corresponds to the given
    # type.
    #
    # @param [#to_s] type
    #   the type of digest to use
    #
    # @return [~Digest]
    #   an instance of the digest class
    #
    def digest_from_type(type)
      id = type.to_s.upcase
      instance = OpenSSL::Digest.const_get(id).new
    end

    #
    # Update the digest with the given contents of the file, reading in small
    # chunks to reduce memory. This method will update the given +digest+
    # parameter, but returns nothing.
    #
    # @param [Digest] digest
    #   the digest to update
    # @param [String] filename
    #   the path to the file on disk to read
    #
    # @return [void]
    #
    def update_with_file_contents(digest, filename)
      File.open(filename) do |io|
        while (chunk = io.read(1024 * 8))
          digest.update(chunk)
        end
      end
    end

    #
    # Update the digest with the given string. This method will update the given
    # +digest+ parameter, but returns nothing.
    #
    # @param [Digest] digest
    #   the digest to update
    # @param [String] string
    #   the string to read
    #
    # @return [void]
    #
    def update_with_string(digest, string)
      digest.update(string)
    end
  end
end
