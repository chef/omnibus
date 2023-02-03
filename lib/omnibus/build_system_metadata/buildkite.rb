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
  class Buildkite

    class << self

      #
      # Constants for the buildkite environment variables
      #
      AMI_ID_ENV_KEY = "BUILDKITE_AGENT_META_DATA_AWS_AMI_ID".freeze
      HOSTNAME_ENV_KEY = "BUILDKITE_AGENT_META_DATA_HOSTNAME".freeze
      DOCKER_VERSION_ENV_KEY = "BUILDKITE_AGENT_META_DATA_DOCKER".freeze
      BUILDKITE_COMMAND_ENV_KEY = "BUILDKITE_COMMAND".freeze

      #
      # The AMI ID of the instance the build is happening on.
      #
      # @note This is only present when the instance is a Windows or Linux instance.
      #
      # @note Relies on presence of ENV["BUILDKITE_AGENT_META_DATA_AWS_AMI_ID"] in Buildkite build job.
      #
      # @return [String]
      #   either the AMI ID, or 'unknown'
      #
      def ami_id
        ami_id = "unknown"
        if !ENV[AMI_ID_ENV_KEY].nil? && !ENV[AMI_ID_ENV_KEY].empty?
          ami_id = ENV[AMI_ID_ENV_KEY]
        end
        ami_id
      end

      #
      # The hostname of the instance the build is happening on.
      #
      # @note This is only present when the instance is a MacOS instance.
      #
      # @note Relies on presence of ENV["BUILDKITE_AGENT_META_DATA_HOSTNAME"] in Buildkite build job.
      #
      # @return [String]
      #   either the hostname, or 'unknown'
      #
      def hostname
        hostname = "unknown"
        if !ENV[HOSTNAME_ENV_KEY].nil? && !ENV[HOSTNAME_ENV_KEY].empty? && ami_id == "unknown"
          hostname = ENV[HOSTNAME_ENV_KEY]
        end
        hostname
      end

      #
      # A boolean representing if the build is using docker or not.
      #
      # @note Relies on presence of ENV["BUILDKITE_AGENT_META_DATA_DOCKER"] in Buildkite build job.
      #
      # @return [Boolean]
      #
      def is_docker_build
        !ENV[DOCKER_VERSION_ENV_KEY].nil? && !ENV[DOCKER_VERSION_ENV_KEY].empty? ? true : false
      end

      #
      # The version of docker that was used in the build.
      #
      # @note Relies on presence of ENV["BUILDKITE_AGENT_META_DATA_DOCKER"] in Buildkite build job.
      #
      # @return [String]
      #
      def docker_version
        ENV[DOCKER_VERSION_ENV_KEY] if is_docker_build
      end

      #
      # The OS Image that is being used in the Docker build
      #
      # @note Relies on presence of ENV["BUILDKITE_COMMAND"] in Buildkite build job.
      #
      # @return [String]
      #   String with the parameter that was provided in the `docker build` command
      #
      def docker_image
        buildkite_command = ENV[BUILDKITE_COMMAND_ENV_KEY]
        if is_docker_build && buildkite_command && buildkite_command.include?("OS_IMAGE")
          os_image = buildkite_command.match(/OS_IMAGE=(?<image_id>[\S]*)/)
          os_image[:image_id]
        end
      end

      #
      # The version of Omnibus that is in `version.rb`
      #
      # @return [String]
      #
      def omnibus_version
        Omnibus::VERSION
      end

      def to_hash
        ret = {}
        ret[:ami_id] = ami_id if ami_id != "unknown"
        ret[:hostname] = hostname if hostname != "unknown"
        ret[:is_docker_build] = is_docker_build if is_docker_build
        ret[:docker_version] = docker_version if docker_version
        ret[:docker_image] = docker_image if docker_image
        ret[:omnibus_version] = omnibus_version
        ret
      end
    end
  end
end