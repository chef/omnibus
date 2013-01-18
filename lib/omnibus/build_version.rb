#
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# License:: Apache License, Version 2.0
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

require 'time'
require 'mixlib/shellout'

module Omnibus
  class BuildVersion

    # This method is still here for compatibility in existing projects.
    def self.full
      puts "#{self.name}.full is deprecated. Use #{self.name}.new.semver or #{self.name}.new.git_describe."
      Omnibus::BuildVersion.new.git_describe
    end

    # Create a new BuildVersion
    #
    # @param [String] path      Path from which to read git version information
    def initialize(path=nil)
      @path = path || Omnibus.root
    end

    #
    # Follows SemVer 2.0.0-rc.1: http://semver.org/
    #
    # Produces a version like:
    #
    #    MAJOR.MINOR.PATCH-PRERELEASE+TIMESTAMP.git.COMMITS_SINCE.GIT_SHA
    #    11.0.0-alpha1+20121218164140.git.207.694b062
    #
    def semver
      build_tag = version_tag
      if prerelease_version?
        # ensure all dashes are dots per precedence rules (#12) in Semver
        # 2.0.0-rc.1
        prerelease = prerelease_tag.gsub("-", ".")
        build_tag << "-" << prerelease
      end
      # TODO: We need a configurable option that allows a build to be marked as
      # a release build and thus leave the build denotation (ie `+` and
      # everything after) bit off.
      build_tag << "+" << build_start_time.strftime("%Y%m%d%H%M%S")
      unless commits_since_tag == 0
        build_tag << "." << ["git", commits_since_tag, git_sha_tag].join(".")
      end
      build_tag
    end

    #
    # Passes the git describe output straight through
    #
    # Produces a version like:
    #
    #    MAJOR.MINOR.PATCH-PRERELEASE-COMMITS_SINCE-gGIT_SHA
    #    11.0.0-alpha1-207-g694b062
    #
    def git_describe
      @git_describe ||= begin
                          git_cmd = "git describe"
                          shell = Mixlib::ShellOut.new(git_cmd,
                                                       :cwd => @path)
                          shell.run_command
                          shell.error!
                          shell.stdout.chomp
                        end
    end

    # 1.2.7-208-ge908a52 -> 1.2.7
    # 11.0.0-alpha-59-gf55b180 -> 11.0.0
    # 11.0.0-alpha2 -> 11.0.0
    # 10.16.2.rc.1 -> 10.16.2
    def version_tag
      version_composition.join(".")
    end

    # 1.2.7-208-ge908a52 -> nil
    # 11.0.0-alpha-59-gf55b180 -> alpha
    # 11.0.0-alpha2 -> alpha2
    # 10.16.2.rc.1 -> rc.1
    def prerelease_tag
      prerelease_regex = if commits_since_tag > 0
                           /^\d+\.\d+\.\d+(?:-|\.)([0-9A-Za-z.-]+)-\d+-g[0-9a-f]+$/
                         else
                           /^\d+\.\d+\.\d+(?:-|\.)([0-9A-Za-z.-]+)$/
                         end
      match = prerelease_regex.match(git_describe)
      match ? match[1] : nil
    end

    # 1.2.7-208-ge908a52 -> e908a52
    # 11.0.0-alpha-59-gf55b180 -> f55b180
    # 11.0.0-alpha2 -> nil
    # 10.16.2.rc.1 -> nil
    def git_sha_tag
      sha_regexp = /g([0-9a-f]+)$/
      match = sha_regexp.match(git_describe)
      match ? match[1] : nil
    end

    # 1.2.7-208-ge908a52 -> 208
    # 11.0.0-alpha-59-gf55b180 -> 59
    # 11.0.0-alpha2 -> 0
    # 10.16.2.rc.1 -> 0
    def commits_since_tag
      commits_regexp = /^.*-(\d+)\-g[0-9a-f]+$/
      match = commits_regexp.match(git_describe)
      match ? match[1].to_i : 0
    end

    def development_version?
      patch = version_composition.last
      patch.to_i.odd?
    end

    def prerelease_version?
      !!(prerelease_tag)
    end

    private

    # We'll attempt to retrive the timestamp from the Jenkin's set BUILD_ID
    # environment variable. This will ensure platform specfic packages for the
    # same build will share the same timestamp.
    def build_start_time
      @build_start_time ||= begin
                              if !ENV['BUILD_ID'].nil?
                                begin
                                  Time.strptime(ENV['BUILD_ID'], "%Y-%m-%d_%H-%M-%S")
                                rescue ArgumentError
                                  error_message =  "BUILD_ID environment variable "
                                  error_message << "should be in YYYY-MM-DD_hh-mm-ss "
                                  error_message << "format."
                                  raise ArgumentError, error_message
                                end
                              else
                                Time.now.utc
                              end
                            end
    end

    def version_composition
      version_regexp = /^(\d+)\.(\d+)\.(\d+)/
      version_regexp.match(git_describe)[1..3]
    end

  end
end
