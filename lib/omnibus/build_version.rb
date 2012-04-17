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

module Omnibus
  module BuildVersion

    def self.full
      build_version
    end

    def self.version_tag
      major, minor, patch = version_composition
      "#{major}.#{minor}.#{patch}"
    end

    def self.git_sha
      sha_regexp = /g([0-9a-f]+)$/
      match = sha_regexp.match(build_version)
      match ? match[1] : nil
    end

    def self.commits_since_tag
      commits_regexp = /^\d+\.\d+\.\d+\-(\d+)\-g[0-9a-f]+$/
      match = commits_regexp.match(build_version)
      match ? match[1].to_i : 0
    end

    def self.development_version?
      major, minor, patch = version_composition
      patch.to_i.odd?
    end

    private

    def self.build_version
      @build_version ||= begin
                           git_cmd = "git describe"
                           shell = Mixlib::ShellOut.new(git_cmd,
                                                        :cwd => Omnibus.root)
                           shell.run_command
                           shell.error!
                           shell.stdout.chomp
                         end
    end

    def self.version_composition
      version_regexp = /^(\d+)\.(\d+)\.(\d+)/
      version_regexp.match(build_version)[1..3]
    end

  end
end
