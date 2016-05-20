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
  class GitFetcher < Fetcher
    #
    # A fetch is required if the git repository is not cloned or if the local
    # revision does not match the desired revision.
    #
    # @return [true, false]
    #
    def fetch_required?
      !(cloned? && contains_revision?(resolved_version))
    end

    #
    # The version identifier for this git location. This is computed using the
    # current revision on disk.
    #
    # @return [String]
    #
    def version_guid
      "git:#{current_revision}"
    end

    #
    # Clean the project directory by resetting the current working tree to
    # the required revision.
    #
    # @return [true, false]
    #   true if the project directory was cleaned, false otherwise.
    #   In our case, we always return true because we always call
    #   git checkout/clean.
    #
    def clean
      log.info(log_key) { "Cleaning existing clone" }
      git_checkout
      git("clean -fdx")
      true
    end

    #
    # Fetch (clone) or update (fetch) the remote git repository.
    #
    # @return [void]
    #
    def fetch
      log.info(log_key) { "Fetching from `#{source_url}'" }
      create_required_directories

      if cloned?
        git_fetch
      else
        force_recreate_project_dir! unless dir_empty?(project_dir)
        git_clone
      end
    end

    #
    # The version for this item in the cache.
    #
    # This method is called *before* clean but *after* fetch. Do not ever
    # use the contents of the project_dir here.
    #
    # We aren't including the source/repo path here as there could be
    # multiple branches/tags that all point to the same commit. We're
    # assuming that we won't realistically ever get two git commits
    # that are unique but share sha1s.
    #
    # TODO: Does this work with submodules?
    #
    # @return [String]
    #
    def version_for_cache
      "revision:#{resolved_version}"
    end

    private

    #
    # The URL where the git source should be downloaded from.
    #
    # @return [String]
    #
    def source_url
      source[:git]
    end

    #
    # Determine if submodules should be cloned.
    #
    # @return [true, false]
    #
    def clone_submodules?
      source[:submodules] || false
    end

    #
    # Determine if a directory is empty
    #
    # @return [true, false]
    #
    def dir_empty?(dir)
      Dir.entries(dir).reject { |d| [".", ".."].include?(d) }.empty?
    end

    #
    # Forcibly remove and recreate the project directory
    #
    def force_recreate_project_dir!
      log.warn(log_key) { "Removing existing directory #{project_dir} before cloning" }
      FileUtils.rm_rf(project_dir)
      Dir.mkdir(project_dir)
    end

    #
    # Determine if the clone exists.
    #
    # @return [true, false]
    #
    def cloned?
      File.exist?("#{project_dir}/.git")
    end

    #
    # Clone the +source_url+ into the +project_dir+.
    #
    # @return [void]
    #
    def git_clone
      git("clone#{" --recursive" if clone_submodules?} #{source_url} .")
    end

    #
    # Checkout the +resolved_version+.
    #
    # @return [void]
    #
    def git_checkout
      # We are hoping to perform a checkout with detached HEAD (that's the
      # default when a sha1 is provided).  git older than 1.7.5 doesn't
      # support the --detach flag.
      git("checkout #{resolved_version} -f -q")
      git("submodule update --recursive") if clone_submodules?
    end

    #
    # Fetch the remote tags and refs, and reset to +resolved_version+.
    #
    # @return [void]
    #
    def git_fetch
      fetch_cmd = "fetch #{source_url} #{described_version}"
      fetch_cmd << " --recurse-submodules=on-demand" if clone_submodules?
      git(fetch_cmd)
    end

    #
    # The current revision for the cloned checkout.
    #
    # @return [String]
    #
    def current_revision
      cmd = git("rev-parse HEAD")
      cmd.stdout.strip
    rescue CommandFailed
      log.debug(log_key) { "unable to determine current revision" }
      nil
    end

    #
    # Check if the current clone has the requested commit id.
    #
    # @return [true, false]
    #
    def contains_revision?(rev)
      cmd = git("cat-file -t #{rev}")
      cmd.stdout.strip == "commit"
    rescue CommandFailed
      log.debug(log_key) { "unable to determine presence of commit #{rev}" }
      false
    end

    #
    # Execute the given git command, inside the +project_dir+.
    #
    # autcrlf is a hack to help support windows and posix clients using the
    # same repository but canonicalizing files as they are committed to the
    # repo but converting line endings when they are actually checked out
    # into a working tree. We do not want to change the on-disk representation
    # of our sources regardless of the platform we are building on unless
    # explicitly asked for. Hence, we disable autocrlf.
    #
    # @see Util#shellout!
    #
    # @return [Mixlib::ShellOut]
    #   the shellout object
    #
    def git(command)
      shellout!("git -c core.autocrlf=false #{command}", cwd: project_dir)
    end

    # Class methods
    public

    # Return the SHA1 corresponding to a ref as determined by the remote source.
    #
    # @return [String]
    #
    def self.resolve_version(ref, source)
      if sha_hash?(ref)
        # A git server negotiates in terms of refs during the info-refs phase
        # of a fetch. During upload-pack, the client is not allowed to specify
        # any sha1s in the "wants" unless the server has publicized them during
        # info-refs. Hence, the server is allowed to drop requests to fetch
        # particular sha1s, even if it is an otherwise reachable commit object.
        # Only when the service is specifically configured with
        # uploadpack.allowReachableSHA1InWant is there any guarantee that it
        # considers "naked" wants.
        log.warn(log_key) { "git fetch on a sha1 is not guaranteed to work" }
        log.warn(log_key) { "Specify a ref name instead of #{ref} on #{source}" }
        ref
      else
        revision_from_remote_reference(ref, source)
      end
    end

    #
    # Determine if the given revision is a SHA
    #
    # @return [true, false]
    #
    def self.sha_hash?(rev)
      rev =~ /^[0-9a-f]{4,40}$/i
    end

    #
    # Return the SHA corresponding to ref.
    #
    # If ref is an annotated tag, return the SHA that was tagged not the SHA of
    # the tag itself.
    #
    # @return [String]
    #
    def self.revision_from_remote_reference(ref, source)
      # execute `git ls-remote` the trailing '*' does globbing. This
      # allows us to return the SHA of the tagged commit for annotated
      # tags. We take care to only return exact matches in
      # process_remote_list.
      remote_list = shellout!("git ls-remote \"#{source[:git]}\" \"#{ref}*\"").stdout
      commit_ref = dereference_annotated_tag(remote_list, ref)

      unless commit_ref
        raise UnresolvableGitReference.new(ref)
      end
      commit_ref
    end

    #
    # Dereference annotated tags.
    #
    # The +remote_list+ parameter is assumed to look like this:
    #
    #   a2ed66c01f42514bcab77fd628149eccb4ecee28        refs/tags/rel-0.11.0
    #   f915286abdbc1907878376cce9222ac0b08b12b8        refs/tags/rel-0.11.0^{}
    #
    # The SHA with ^{} is the commit pointed to by an annotated
    # tag. If ref isn't an annotated tag, there will not be a line
    # with trailing ^{}.
    #
    # @param [String] remote_list
    #   output from `git ls-remote origin` command
    # @param [String] ref
    #   the target git ref
    #
    # @return [String]
    #
    def self.dereference_annotated_tag(remote_list, ref)
      # We'll return the SHA corresponding to the ^{} which is the
      # commit pointed to by an annotated tag. If no such commit
      # exists (not an annotated tag) then we return the SHA of the
      # ref.  If nothing matches, return "".
      lines = remote_list.split("\n")
      matches = lines.map { |line| line.split("\t") }
      # First try for ^{} indicating the commit pointed to by an
      # annotated tag.
      tagged_commit = matches.find { |m| m[1].end_with?("#{ref}^{}") }
      if tagged_commit
        tagged_commit.first
      else
        found = matches.find { |m| m[1].end_with?("#{ref}") }
        if found
          found.first
        else
          nil
        end
      end
    end
  end
end
