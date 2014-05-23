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
  class Artifact
    attr_reader :path
    attr_reader :platforms
    attr_reader :config

    # @param path [String] relative or absolute path to a package file.
    # @param platforms [Array<Array<String, String, String>>] an Array of
    #   distro, distro version, architecture tuples. By convention, the first
    #   platform is the platform on which the artifact was built.
    # @param config [#Hash<Symbol, Object>] configuration for the release.
    #   Artifact only uses `:build_version => String`.
    def initialize(path, platforms, config)
      @path = path
      @platforms = platforms
      @config = config
    end

    # Metadata about the artifact as a flat Hash.
    #
    # @example For a RHEL/CentOS 6, 64-bit package of project version 11.4.0-1
    #   flat_metadata
    #     { "platform" => "el",
    #       "platform_version" => "6",
    #       "arch" => "x86_64",
    #       "version" => "11.4.0-1",
    #       "md5" => "d41d8cd98f00b204e9800998ecf8427e",
    #       "sha256" => "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" }
    #
    # @return [Hash{String=>String}] the artifact metadata
    def flat_metadata
      distro, version, arch = build_platform
      {
        'platform' => distro,
        'platform_version' => version,
        'arch' => arch,
        'version' => build_version,
        'basename' => File.basename(path),
        # 'md5' => md5,
        # 'sha256' => sha256,
      }
    end

    # Platform on which the artifact was built. By convention, this is the
    # first in the list of platforms passed to {#initialize}.
    # @return [Array<String, String, String>] an Array of distro, distro
    #   version, architecture.
    def build_platform
      platforms.first
    end

    # @return [String] build version of the project.
    def build_version
      config[:version]
    end
  end
end
