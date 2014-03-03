#
# Copyright:: Copyright (c) 2012-2014 Chef Software, Inc.
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

require 'omnibus/exceptions'

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
      <<-E
repo URI:       #{@source[:git]}
local location: #{@project_dir}
E
    end

    def version_guid
      "git:#{current_revision}".chomp
    rescue
    end

    def clean
      if existing_git_clone?
        log 'cleaning existing build'
        clean_cmd = 'git clean -fdx'
        shell = Mixlib::ShellOut.new(clean_cmd, live_stream: STDOUT, cwd: project_dir)
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
      retries ||= 0
      if existing_git_clone?
        fetch_updates unless current_rev_matches_target_rev?
      else
        clone
        checkout
      end
    rescue Exception => e
      if retries >= 3
        ErrorReporter.new(e, self).explain("Failed to fetch git repository '#{@source[:git]}'")
        raise
      else
        # Deal with github failing all the time :(
        time_to_sleep = 5 * (2**retries)
        retries += 1
        log "git clone/fetch failed for #{@source} #{retries} time(s), retrying in #{time_to_sleep}s"
        sleep(time_to_sleep)
        retry
      end
    end

    private

    def clone
      puts 'cloning the source from git'
      clone_cmd = "git clone #{@source[:git]} #{project_dir}"
      shell = Mixlib::ShellOut.new(clone_cmd, live_stream: STDOUT)
      shell.run_command
      shell.error!
    end

    def checkout
      sha_ref = target_revision

      checkout_cmd = "git checkout #{sha_ref}"
      shell = Mixlib::ShellOut.new(checkout_cmd, live_stream: STDOUT, cwd: project_dir)
      shell.run_command
      shell.error!
    end

    def fetch_updates
      puts "fetching updates and resetting to revision #{target_revision}"
      fetch_cmd = "git fetch origin && git fetch origin --tags && git reset --hard #{target_revision}"
      shell = Mixlib::ShellOut.new(fetch_cmd, live_stream: STDOUT, cwd: project_dir)
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
                         rev_cmd = 'git rev-parse HEAD'
                         shell = Mixlib::ShellOut.new(rev_cmd, live_stream: STDOUT, cwd: project_dir)
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

    # Return the SHA corresponding to ref. If ref is an annotated tag,
    # return the SHA that was tagged not the SHA of the tag itself.
    def revision_from_remote_reference(ref)
      retries ||= 0
      # execute `git ls-remote` the trailing '*' does globbing. This
      # allows us to return the SHA of the tagged commit for annotated
      # tags. We take care to only return exact matches in
      # process_remote_list.
      cmd = "git ls-remote origin #{ref}*"
      shell = Mixlib::ShellOut.new(cmd, live_stream: STDOUT, cwd: project_dir)
      shell.run_command
      shell.error!
      commit_ref = process_remote_list(shell.stdout, ref)

      unless commit_ref
        raise UnresolvableGitReference.new("Could not resolve `#{ref}' to a SHA.")
      end
      commit_ref
    rescue UnresolvableGitReference => e # skip retries
      ErrorReporter.new(e, self).explain(<<-E)
Command `#{cmd}' did not find a commit for reference `#{ref}'.
The tag or branch you're looking for doesn't exist on the remote repo.
If your project uses version tags like v1.2.3, include the 'v' in your
software's version.
E
      raise
    rescue Exception => e
      if retries >= 3
        ErrorReporter.new(e, self).explain("Failed to find any commits for the ref '#{ref}'")
        raise
      else
        # Deal with github failing all the time :(
        time_to_sleep = 5 * (2**retries)
        retries += 1
        log "git ls-remote failed for #{@source} #{retries} time(s), retrying in #{time_to_sleep}s"
        sleep(time_to_sleep)
        retry
      end
    end

    def process_remote_list(stdout, ref)
      # Dereference annotated tags.
      #
      # Output will look like this:
      #
      # a2ed66c01f42514bcab77fd628149eccb4ecee28        refs/tags/rel-0.11.0
      # f915286abdbc1907878376cce9222ac0b08b12b8        refs/tags/rel-0.11.0^{}
      #
      # The SHA with ^{} is the commit pointed to by an annotated
      # tag. If ref isn't an annotated tag, there will not be a line
      # with trailing ^{}.
      #
      # We'll return the SHA corresponding to the ^{} which is the
      # commit pointed to by an annotated tag. If no such commit
      # exists (not an annotated tag) then we return the SHA of the
      # ref.  If nothing matches, return "".
      lines = stdout.split("\n")
      matches = lines.map { |line| line.split("\t") }
      # first try for ^{} indicating the commit pointed to by an
      # annotated tag
      tagged_commit = matches.find { |m| m[1].end_with?("#{ref}^{}") }
      if tagged_commit
        tagged_commit[0]
      else
        found = matches.find { |m| m[1].end_with?("#{ref}") }
        if found
          found[0]
        else
          nil
        end
      end
    end
  end
end
