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
require "spec_helper"

module Omnibus
  describe SemanticVersion do

    it "raises an InvalidVersion error if it doesn't understand the format" do
      expect { Omnibus::SemanticVersion.new("wut") }.to raise_error(Omnibus::InvalidVersion)
    end

    it "preserves leading the leading v when printing the string" do
      v = Omnibus::SemanticVersion.new("v1.0.0")
      expect(v.to_s).to eq("v1.0.0")
    end

    it "can bump the patch version" do
      v = Omnibus::SemanticVersion.new("1.0.0")
      expect(v.next_patch.to_s).to eq("1.0.1")
    end

    it "can bump the minor version" do
      v = Omnibus::SemanticVersion.new("1.1.0")
      expect(v.next_minor.to_s).to eq("1.2.0")
    end

    it "can bump the major version" do
      v = Omnibus::SemanticVersion.new("1.0.0")
      expect(v.next_major.to_s).to eq("2.0.0")
    end

    it "resets the patch version when bumping minor versions" do
      v = Omnibus::SemanticVersion.new("1.1.1")
      expect(v.next_minor.to_s).to eq("1.2.0")
    end

    it "resets the patch and minor version when bumping major versions" do
      v = Omnibus::SemanticVersion.new("1.1.1")
      expect(v.next_major.to_s).to eq("2.0.0")
    end
  end
end
