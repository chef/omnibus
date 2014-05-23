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

      File.open(path) do |io|
        while (chunk = io.read(1024 * 8))
          instance.update(chunk)
        end
      end

      instance.hexdigest
    end
  end
end
