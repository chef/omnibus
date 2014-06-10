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

require 'digest'

module Omnibus
  module Digestable
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
    #
    def digest(path, type = :md5)
      id = type.to_s.upcase
      instance = Digest.const_get(id).new
      update_with_file_contents(instance, path)
      instance.hexdigest
    end

    #
    # Calculate the digest of a directory at the given path.
    # Each file in the directory is read in binary chunks to
    # prevent excess memory usage. Filesystem entries of all
    # types are included in the digest,  including directories,
    # links, and sockets. The contents of non-file entries are
    # represented as:
    #
    #   $type $path
    #
    # while the contents of regular files are represented as:
    #
    #   file $path
    #
    # and then appended by the binary contents of the file
    #
    # @param [String] path
    #   the path of the directory to digest
    # @param [Symbol] type
    #   the type of digest to use
    def digest_directory(path, type = :md5)
      id = type.to_s.upcase
      instance = Digest.const_get(id).new

      glob = Dir.glob("#{path}/**/*")
      glob.each do |filename|
        case ftype = File.ftype(filename)
        when 'file'
          update_with_string(instance, "#{ftype} #{filename}")
          update_with_file_contents(instance, filename)
        else
          update_with_string(instance, "#{ftype} #{filename}")
        end
      end

      instance.hexdigest
    end

    private

    def update_with_file_contents(digest, filename)
      File.open(filename) do |io|
        while (chunk = io.read(1024 * 8))
          digest.update(chunk)
        end
      end
    end

    def update_with_string(digest, string)
      digest.update(string)
    end
  end
end
