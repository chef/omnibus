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

require "pathname"
require "omnibus/packagers/windows_base"
require "fileutils"

module Omnibus
  class Packager::XZ < Packager::Base
    id :xz

    setup do
    end

    build do
      out_file = windows_safe_path(Config.package_dir, archive_name)
      out_source_path = "#{windows_safe_path(project.install_dir)}/*"
      compress_env = { "XZ_OPT" => "-T#{compression_threads} -#{compression_level}" }
      cmd = <<-EOH.split.join(" ").squeeze(" ").strip
        tar -cJf
        #{out_file}
        #{out_source_path}
      EOH
      shellout!(cmd, environment: compress_env)
    end

    def debug_build?
      false
    end

    # @see Base#package_name
    def package_name
      archive_name
    end

    def archive_name
      "#{project.package_name}-#{project.build_version}-#{project.build_iteration}-#{safe_architecture}.tar.xz"
    end

    #
    # Set or return the architecture to set in the DEB control file
    #
    # @example
    #   safe_architecture 'all'
    #
    # @param [String] val
    #   A valid architecture for DEB control file
    #
    # @return [String]
    #   the architecture
    #
    def safe_architecture(val = NULL)
      val = shellout!("uname --processor").stdout.strip

      val = case val
            when "x86_64", "x64", "amd64" then "amd64"
            when "arm64", "aarch64" then "arm64"
            when "armv7l" then "arm"
            else raise ArgumentError, "Unknown architecture '#{val}'"
            end
      val
    end

    def compression_threads(val = nil)
      if val.nil?
        @compression_threads || 1
      else
        unless val > 0 && val < 32
          raise InvalidValue.new(:compression_threads, 'be a stricly positive and lower than 32 Integer')
        end

        @compression_threads = val
      end
    end
    expose :compression_threads

    def compression_level(val = nil)
      if val.nil?
        @compression_level || 6
      else
        unless val >= 0 && val <= 9
          raise InvalidValue.new(:compression_level, 'be an Integer between 0 and 9 included')
        end

        @compression_level = val
      end
    end
    expose :compression_level
  end
end
