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

require "time"

module Omnibus
  # Provides methods for generating Omnibus project build version
  # strings automatically from Git repository information.
  #
  # @see Omnibus::Project#build_version
  #
  # @note Requires a Git repository
  #
  # @todo Rename this class to reflect its absolute dependence on running in a
  #   Git repository.
  class BuildVersion
    include Logging
    include Util

    # Formatting string for the timestamp component of our SemVer build specifier.
    #
    # @see Omnibus::BuildVersion#semver
    # @see Time#strftime
    TIMESTAMP_FORMAT = "%Y%m%d%H%M%S"

    class << self
      # @see (BuildVersion#git_describe)
      def git_describe
        new.git_describe
      end

      # @see (BuildVersion#semver)
      def semver
        new.semver
      end

      def build_start_time
        new.build_start_time
      end
    end

    # Create a new BuildVersion
    #
    # @param [String] path
    #   Path from which to read git version information
    def initialize(path = Config.project_root)
      @path = path
    end

    # @!group Version Generator Methods

    # Generate a {http://semver.org/ SemVer 2.0.0-rc.1 compliant}
    # version string for an Omnibus project.
    #
    # This relies on the Omnibus project being a Git repository, as
    # well as having tags named according to SemVer conventions
    # (specifically, the `MAJOR.MINOR.PATCH-PRERELEASE` aspects)
    #
    # The specific format of the version string is:
    #
    #     MAJOR.MINOR.PATCH-PRERELEASE+TIMESTAMP.git.COMMITS_SINCE.GIT_SHA
    #
    # By default, a timestamp is incorporated into the build component of
    # version string (see {Omnibus::BuildVersion::TIMESTAMP_FORMAT}). This
    # option is configurable via the {Config}.
    #
    # @example 11.0.0-alpha.1+20121218164140.git.207.694b062
    # @return [String]
    # @see #git_describe
    # @todo Issue a warning or throw an exception if the tags of the
    #   repository are not themselves SemVer-compliant?
    # @todo Consider making the {#build_start_time} method public, as
    #   its function influences how build timestamps are generated,
    #   and can be influenced by users.
    def semver
      build_tag = version_tag

      # PRERELEASE VERSION
      if prerelease_version?
        # ensure all dashes are dots per precedence rules (#12) in Semver
        # 2.0.0-rc.1
        prerelease = prerelease_tag.tr("-", ".")
        build_tag << "-" << prerelease
      end

      # BUILD VERSION
      # Follows SemVer conventions and the build version begins with a '+'.
      build_version_items = []

      # By default we will append a timestamp to every build. This behavior can
      # be overriden by setting the OMNIBUS_APPEND_TIMESTAMP environment
      # variable to a 'falsey' value (ie false, f, no, n or 0).
      #
      # format: YYYYMMDDHHMMSS example: 20130131123345
      if Config.append_timestamp
        build_version_items << build_start_time
      end

      # We'll append the git describe information unless we are sitting right
      # on an annotated tag.
      #
      # format: git.COMMITS_SINCE_TAG.GIT_SHA example: git.207.694b062
      unless commits_since_tag == 0
        build_version_items << ["git", commits_since_tag, git_sha_tag].join(".")
      end

      unless build_version_items.empty?
        build_tag << "+" << build_version_items.join(".")
      end

      build_tag
    end

    # We'll attempt to retrive the timestamp from the Jenkin's set BUILD_ID
    # environment variable. This will ensure platform specfic packages for the
    # same build will share the same timestamp.
    def build_start_time
      @build_start_time ||= begin
                              if ENV["BUILD_ID"]
                                begin
                                  Time.strptime(ENV["BUILD_ID"], "%Y-%m-%d_%H-%M-%S")
                                rescue ArgumentError
                                  error_message =  "BUILD_ID environment variable "
                                  error_message << "should be in YYYY-MM-DD_hh-mm-ss "
                                  error_message << "format."
                                  raise ArgumentError, error_message
                                end
                              else
                                Time.now.utc
                              end
                            end.strftime(TIMESTAMP_FORMAT)
    end

    # Generates a version string compliant with Datadog agent stable/nightly builds
    # It works as a patch on top of Omnibus::BuildVersion#semver.
    # Returns:
    #  - For stable builds: `semver` output
    #  - For nightly builds: AGENT_VERSION+git.COMMITS_SINCE.GIT_SHA
    #    (where `AGENT_VERSION` is an environment variable)
    def dd_agent_format
      agent_version = semver
      if ENV['AGENT_VERSION'] and ENV['AGENT_VERSION'].length > 1 and agent_version.include? "git"
        agent_version = ENV['AGENT_VERSION'] + "." + agent_version.split("+")[1]
      end
      agent_version
    end

    # Generates a version string by running
    # {https://www.kernel.org/pub/software/scm/git/docs/git-describe.html
    # git describe} in the root of the Omnibus project.
    #
    # Produces a version string of the format
    #
    #     MOST_RECENT_TAG-COMMITS_SINCE-gGIT_SHA
    #
    # @example
    #  11.0.0-alpha.1-207-g694b062
    # @return [String]
    def git_describe
      @git_describe ||= begin
        cmd = shellout("git describe --tags", cwd: @path)

        if cmd.exitstatus == 0
          cmd.stdout.chomp
        else
          log.warn(log_key) do
            "Could not extract version information from 'git describe'! " \
            "Setting version to 0.0.0."
          end
          "0.0.0"
        end
      end
    end

    # @!endgroup

    # Note: The remaining methods could just as well be private

    # Return a `MAJOR.MINOR.PATCH` version string, as extracted from
    # {#git_describe}.
    #
    # Here are some illustrative examples:
    #
    #     1.2.7-208-ge908a52 -> 1.2.7
    #     11.0.0-alpha-59-gf55b180 -> 11.0.0
    #     11.0.0-alpha2 -> 11.0.0
    #     10.16.2.rc.1 -> 10.16.2
    #
    # @return [String]
    def version_tag
      version_composition.join(".")
    end

    # Return a prerelease tag string (if it exists), as extracted from {#git_describe}.
    #
    # Here are some illustrative examples:
    #
    #     1.2.7-208-ge908a52 -> nil
    #     11.0.0-alpha-59-gf55b180 -> alpha
    #     11.0.0-alpha2 -> alpha2
    #     10.16.2.rc.1 -> rc.1
    #
    # @return [String] if a pre-release tag was found
    # @return [nil] if no pre-release tag was found
    def prerelease_tag
      prerelease_regex = if commits_since_tag > 0
                           /^v?\d+\.\d+\.\d+(?:-|\.)([0-9A-Za-z.-]+)-\d+-g[0-9a-f]+$/
                         else
                           /^v?\d+\.\d+\.\d+(?:-|\.)([0-9A-Za-z.-]+)$/
                         end
      match = prerelease_regex.match(git_describe)
      match ? match[1] : nil
    end

    # Extracts the 7-character truncated Git SHA1 from the output of {#git_describe}.
    #
    # Here are some illustrative examples:
    #
    #     1.2.7-208-ge908a52 -> e908a52
    #     11.0.0-alpha-59-gf55b180 -> f55b180
    #     11.0.0-alpha2 -> nil
    #     10.16.2.rc.1 -> nil
    #
    # @return [String] the truncated SHA1
    # @return [nil] if no SHA1 is present in the output of #{git_describe}
    def git_sha_tag
      sha_regexp = /g([0-9a-f]+)$/
      match = sha_regexp.match(git_describe)
      match ? match[1] : nil
    end

    # Extracts the number of commits since the most recent Git tag, as
    # determined by {#git_describe}.
    #
    # Here are some illustrative examples:
    #
    #     1.2.7-208-ge908a52 -> 208
    #     11.0.0-alpha-59-gf55b180 -> 59
    #     11.0.0-alpha2 -> 0
    #     10.16.2.rc.1 -> 0
    #
    # @return [Fixnum]
    def commits_since_tag
      commits_regexp = /^.*-(\d+)\-g[0-9a-f]+$/
      match = commits_regexp.match(git_describe)
      match ? match[1].to_i : 0
    end

    # Indicates whether the version represents a pre-release or not, as
    # signalled by the presence of a pre-release tag in the version
    # string.
    #
    # @return [Boolean]
    # @see #prerelease_tag
    def prerelease_version?
      if prerelease_tag
        true
      else
        false
      end
    end

    private

    # Pulls out the major, minor, and patch components from the output
    # of {#git_describe}.
    #
    # Relies on the most recent Git tag being SemVer compliant (i.e.,
    # starting with a `MAJOR.MINOR.PATCH` string)
    #
    # @return [Array<(String, String, String)>]
    #
    # @todo Compute this once and store the result in an instance variable
    def version_composition
      version_regexp = /^v?(\d+)\.(\d+)\.(\d+)/

      if match = version_regexp.match(git_describe)
        match[1..3]
      else
        raise "Invalid semver tag `#{git_describe}'!"
      end
    end
  end
end
