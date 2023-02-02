#
# Copyright 2012-2018 Chef Software, Inc.
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

require "omnibus/build_system_metadata/buildkite"

module Omnibus
  # Provides methods for fetching Omnibus project build metadata from Buildkite
  #
  # @note Requires environment variables provided whichever platform metdata is being pulled from
  #
  class BuildSystemMetadata

    class << self

      def to_hash
        if !ENV["BUILDKITE"].nil? && !ENV["BUILDKITE"].empty?
          Omnibus::Buildkite.to_hash
        end
      end

    end
  end
end