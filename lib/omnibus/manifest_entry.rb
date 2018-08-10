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

module Omnibus
  class ManifestEntry
    attr_reader :locked_version, :locked_source, :source_type, :described_version, :name, :license
    def initialize(name, manifest_data)
      @name = name
      @locked_version = manifest_data[:locked_version]
      @locked_source = manifest_data[:locked_source]
      @source_type = manifest_data[:source_type]
      @described_version = manifest_data[:described_version]
      @license = manifest_data[:license]
    end

    def to_hash
      {
        locked_version: @locked_version,
        locked_source: @locked_source,
        source_type: @source_type,
        described_version: @described_version,
        license: @license,
      }
    end

    def ==(other)
      if other.is_a?(ManifestEntry)
        (to_hash == other.to_hash) && (name == other.name)
      end
    end
  end
end
