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

require "ffi_yajl"

module Omnibus
  class Manifest
    class InvalidManifestFormat < Exception; end
    class NotAManifestEntry < Exception; end
    class MissingManifestEntry < Exception; end

    include Logging

    LATEST_MANIFEST_FORMAT = 2

    attr_reader :build_version, :build_git_revision, :license
    def initialize(version = nil, git_rev = nil, license = "Unspecified")
      @data = {}
      @build_version = version
      @build_git_revision = git_rev
      @license = license
    end

    def entry_for(name)
      name_sym = name.to_sym
      if @data.key?(name_sym)
        @data[name_sym]
      else
        raise MissingManifestEntry, "No manifest entry found for #{name}"
      end
    end

    def add(name, entry)
      if !entry.is_a? Omnibus::ManifestEntry
        raise NotAManifestEntry, "#{entry} is not an Omnibus:ManifestEntry"
      end

      name_sym = name.to_sym
      if @data.key?(name_sym)
        log.warn(log_key) { "Overritting existing manifest entry for #{name}" }
      end

      @data[name_sym] = entry
      self
    end

    def each
      @data.each do |key, entry|
        yield entry
      end
    end

    def entry_names
      @data.keys
    end

    def to_hash
      software_hash = @data.inject({}) do |memo, (k, v)|
        memo[k] = v.to_hash
        memo
      end
      ret = {
        manifest_format: LATEST_MANIFEST_FORMAT,
        software: software_hash,
      }
      ret[:build_version] = build_version if build_version
      ret[:build_git_revision] = build_git_revision if build_git_revision
      ret[:license] = license
      ret
    end

    #
    # The JSON representation of this build manifest.
    #
    # @return [String]
    #
    def to_json
      FFI_Yajl::Encoder.encode(to_hash, pretty: true)
    end

    #
    # Class Methods
    #

    def self.from_hash(manifest_data)
      case manifest_data[:manifest_format].to_i
      when 1
        from_hash_v1(manifest_data)
      when 2
        from_hash_v2(manifest_data)
      else
        raise InvalidManifestFormat, "Unknown manifest format version: #{manifest_data[:manifest_format]}"
      end
    end

    def self.from_hash_v1(manifest_data)
      m = Omnibus::Manifest.new(manifest_data[:build_version], manifest_data[:build_git_revision])
      manifest_data[:software].each do |name, entry_data|
        m.add(name, Omnibus::ManifestEntry.new(name, keys_to_syms(entry_data)))
      end
      m
    end

    def self.from_hash_v2(manifest_data)
      m = Omnibus::Manifest.new(manifest_data[:build_version], manifest_data[:build_git_revision], manifest_data[:license])
      manifest_data[:software].each do |name, entry_data|
        m.add(name, Omnibus::ManifestEntry.new(name, keys_to_syms(entry_data)))
      end
      m
    end

    def self.from_file(filename)
      data = File.read(File.expand_path(filename))
      hash = FFI_Yajl::Parser.parse(data, symbolize_names: true)
      from_hash(hash)
    end

    private

    #
    # Utility function to convert a Hash with String keys to a Hash
    # with Symbol keys, recursively.
    #
    # @returns [Hash]
    #
    def self.keys_to_syms(h)
      h.inject({}) do |memo, (k, v)|
        memo[k.to_sym] = if v.is_a? Hash
                           keys_to_syms(v)
                         else
                           v
                         end
        memo
      end
    end
  end
end
