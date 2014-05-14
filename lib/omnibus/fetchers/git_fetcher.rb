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

module Omnibus
  # Fetcher implementation for projects in git.
  class GitFetcher < Fetcher
    attr_reader :source
    attr_reader :project_dir
    attr_reader :version

    def initialize(software)
      @name         = software.name
      @source       = software.source
      @version      = software.version
      @project_dir  = software.project_dir
      super
    end

    def description
      <<-EOH.gsub(/^ {8}/, '').strip
        repo URI:       #{@source[:git]}
        local location: #{@project_dir}
      EOH
    end

    def version_guid
      "git:#{current_revision}".chomp
    rescue
    end

    def clean
      if existing_git_clone?
        log.info(log_key) { 'Cleaning existing build' }
        quiet_shellout!('git clean -fdx', cwd: project_dir)
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
        log.warn(log_key) do
          "git clone/fetch failed for #{@source} #{retries} time(s). " \
          "Retrying in #{time_to_sleep}s..."
        end
        sleep(time_to_sleep)
        retry
      end
    end

    # Return the target sha to be used during build caching
    # This overrides the cases where software.version is similar to
    # master, 11-stable etc..
    def version_for_cache
      target_revision
    end

    private

    def clone
      log.info(log_key) { 'Cloning the source from git' }
      quiet_shellout!("git clone #{@source[:git]} #{project_dir}")
    end

    def checkout
      sha_ref = target_revision
      quiet_shellout!("git checkout #{sha_ref}", cwd: project_dir)
    end

    def fetch_updates
      log.info(log_key) do
        "Fetching updates and resetting to revision '#{target_revision}'"
      end

      fetch_cmd = "git fetch origin && " \
                  "git fetch origin --tags && " \
                  "git reset --hard #{target_revision}"
      quiet_shellout!(fetch_cmd, cwd: project_dir)
    end

    def existing_git_clone?
      File.exist?("#{project_dir}/.git")
    end

    def current_rev_matches_target_rev?
      current_revision && current_revision.strip.to_i(16) == target_revision.strip.to_i(16)
    end

    def current_revision
      return @current_rev if @current_rev

      cmd = quiet_shellout!('git rev-parse HEAD', cwd: project_dir)
      stdout = cmd.stdout

      @current_rev = sha_hash?(stdout) ? stdout : nil
      @current_rev
    end

    def target_revision
      @target_rev ||= if sha_hash?(version)
                        version
                      else
                        revision_from_remote_reference(version)
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
      cmd = quiet_shellout!("git ls-remote origin #{ref}*", cwd: project_dir)
      commit_ref = process_remote_list(cmd.stdout, ref)

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
        log.warn(log_key) do
          "git ls-remote failed for #{@source} #{retries} time(s). " \
          "Retrying in #{time_to_sleep}s..."
        end
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
