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

module Omnibus
  # Provides methods for fetching Omnibus project build metadata from Buildkite
  #
  # @note Requires environment variables provided by Buildkite
  #
  class BuildkiteMetadata

    class << self

      def ami_id
        ami_id = "unknown"
        if !ENV["BUILDKITE_AGENT_META_DATA_AWS_AMI_ID"].nil? && !ENV["BUILDKITE_AGENT_META_DATA_AWS_AMI_ID"].empty?
          ami_id = ENV["BUILDKITE_AGENT_META_DATA_AWS_AMI_ID"]
        elsif !ENV["BUILDKITE_AGENT_META_DATA_HOSTNAME"].nil? && !ENV["BUILDKITE_AGENT_META_DATA_HOSTNAME"].empty?
          ami_id = ENV["BUILDKITE_AGENT_META_DATA_HOSTNAME"]
        end
        ami_id
      end

      def is_docker_build
        !ENV["BUILDKITE_AGENT_META_DATA_DOCKER"].nil? && !ENV["BUILDKITE_AGENT_META_DATA_DOCKER"].empty? ? true : false
      end

      def docker_version
        ENV["BUILDKITE_AGENT_META_DATA_DOCKER"] if is_docker_build
      end

      def docker_image
        buildkite_command = ENV["BUILDKITE_COMMAND"]
        if is_docker_build && buildkite_command && buildkite_command.include?("OS_IMAGE")
          os_image = buildkite_command.match(/OS_IMAGE=(?<image_id>[\S]*)/)
          os_image[:image_id]
        end
      end

      def omnibus_version
        Omnibus::VERSION
      end

    end
  end
end