#
# Copyright 2015 Chef Software, Inc.
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

require "mixlib/versioning"

module Omnibus
  class SemanticVersion
    def initialize(version_string)
      @prefix = if version_string =~ /^v/
                  "v"
                else
                  ""
                end
      @version = Mixlib::Versioning.parse(version_string.gsub(/^v/, ""))
      if @version.nil?
        raise InvalidVersion, "#{version_string} could not be parsed as a valid version"
      end
    end

    def to_s
      "#{prefix}#{version}"
    end

    def next_patch
      s = [version.major, version.minor, version.patch + 1].join(".")
      self.class.new("#{prefix}#{s}")
    end

    def next_minor
      s = [version.major, version.minor + 1, 0].join(".")
      self.class.new("#{prefix}#{s}")
    end

    def next_major
      s = [version.major + 1, 0, 0].join(".")
      self.class.new("#{prefix}#{s}")
    end

    private

    attr_reader :prefix, :version
  end
end
