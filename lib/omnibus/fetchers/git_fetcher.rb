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
      !(cloned? && same_revision?)
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
    # Clean the project directory by removing the contents from disk.
    #
    # @return [true, false]
    #   true if the project directory was removed, false otherwise
    #
    def clean
      if cloned?
        log.info(log_key) { 'Cleaning existing clone' }
        git('clean -fdx')
        true
      else
        false
      end
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
        git_fetch unless same_revision?
      else
        git_clone
        git_checkout
      end
    end

    #
    # The version for this item in the cache. The is the parsed revision of the
    # item on disk.
    #
    # @return [String]
    #
    def version_for_cache
      "revision:#{current_revision}"
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
      git("clone #{source_url} .")
    end

    #
    # Checkout the +target_revision+.
    #
    # @return [void]
    #
    def git_checkout
      git("fetch --all")
      git("checkout #{target_revision}")
    end

    #
    # Fetch the remote tags and refs, and reset to +target_revision+.
    #
    # @return [void]
    #
    def git_fetch
      git("fetch --all")
      git("reset --hard #{target_revision}")
    end

    #
    # The current revision for the cloned checkout.
    #
    # @return [String]
    #
    def current_revision
      @current_revision ||= git('rev-parse HEAD').stdout.strip
    rescue CommandFailed
      nil
    end

    #
    # The target revision from the user.
    #
    # @return [String]
    #
    def target_revision
      @target_revision ||= git("rev-parse #{version}").stdout.strip
    rescue CommandFailed => e
      if e.message.include?('ambiguous argument')
        @target_revision = git("rev-parse origin/#{version}").stdout.strip
        @target_revision
      else
        log.warn { 'Could not determine target revision!' }
        nil
      end
    end

    #
    # Determine if the given revision matches the current revision.
    #
    # @return [true, false]
    #
    def same_revision?
      current_revision == target_revision
    end

    #
    # Execute the given git command, inside the +project_dir+.
    #
    # @see Util#shellout!
    #
    # @return [Mixlib::ShellOut]
    #   the shellout object
    #
    def git(command)
      shellout!("git #{command}", cwd: project_dir)
    end
  end
end
