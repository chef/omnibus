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

  # Fetcher implementation for projects in git.
  class GitFetcher < Fetcher

    name :git

    attr_reader :source
    attr_reader :project_dir
    attr_reader :version

    def initialize(software)
      @name         = software.name
      @source       = software.source
      @version      = software.version
      @project_dir  = software.project_dir
    end

    def description
      s=<<-E
repo URI:       #{@source[:git]}
local location: #{@project_dir}
E
    end
    
    def clean
      if existing_git_clone?
        log "cleaning existing build"
        clean_cmd = "git clean -fdx"
        shell = Mixlib::ShellOut.new(clean_cmd, :live_stream => STDOUT, :cwd => project_dir)
        shell.run_command
        shell.error!
      end
    rescue Exception => e
      ErrorReporter.new(e, self).explain("Failed to clean git repository '#{@source[:git]}'")
      raise
    end
    
    def fetch_required?
      !existing_git_clone? || !current_rev_matches_target_rev?
    end

    def fetch
      if existing_git_clone?
        fetch_updates unless current_rev_matches_target_rev?
      else
        clone
        checkout
      end
    rescue Exception => e
      ErrorReporter.new(e, self).explain("Failed to fetch git repository '#{@source[:git]}'")
      raise
    end

    private

    def clone
      puts "cloning the source from git"
      clone_cmd = "git clone #{@source[:git]} #{project_dir}"
      shell = Mixlib::ShellOut.new(clone_cmd, :live_stream => STDOUT)
      shell.run_command
      shell.error!
    end

    def checkout
      sha_ref = target_revision

      checkout_cmd = "git checkout #{sha_ref}"
      shell = Mixlib::ShellOut.new(checkout_cmd, :live_stream => STDOUT, :cwd => project_dir)
      shell.run_command
      shell.error!
    end

    def fetch_updates
      puts "fetching updates and resetting to revision #{target_revision}"
      fetch_cmd = "git fetch origin && git fetch origin --tags && git reset --hard #{target_revision}"
      shell = Mixlib::ShellOut.new(fetch_cmd, :live_stream => STDOUT, :cwd => project_dir)
      shell.run_command
      shell.error!
    end

    def existing_git_clone?
      File.exist?("#{project_dir}/.git")
    end

    def current_rev_matches_target_rev?
      current_revision && current_revision.strip.to_i(16) == target_revision.strip.to_i(16)
    end

    def current_revision
      @current_rev ||= begin
                         rev_cmd = "git rev-parse HEAD"
                         shell = Mixlib::ShellOut.new(rev_cmd, :live_stream => STDOUT, :cwd => project_dir)
                         shell.run_command
                         shell.error!
                         output = shell.stdout

                         sha_hash?(output) ? output : nil
                       end
    end

    def target_revision
      @target_rev ||= begin
                        if sha_hash?(version)
                          version
                        else
                          revision_from_remote_reference(version)
                        end
                      end
    end

    def sha_hash?(rev)
      rev =~ /^[0-9a-f]{40}$/
    end

    def revision_from_remote_reference(ref)
      # execute `git ls-remote`
      cmd = "git ls-remote origin #{ref}"
      shell = Mixlib::ShellOut.new(cmd, :live_stream => STDOUT, :cwd => project_dir)
      shell.run_command
      shell.error!
      stdout = shell.stdout

      # parse the output for the git SHA
      unless stdout =~ /^([0-9a-f]{40})\s+(\S+)/
        raise "Could not parse SHA reference"
      end
      return $1
    end
  end
end
