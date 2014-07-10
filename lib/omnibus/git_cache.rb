#
# Copyright 2014 Chef Software, Inc.
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

require 'digest'
require 'fileutils'

module Omnibus
  class GitCache
    include Util

    def initialize(install_dir, software)
      @install_dir = install_dir.sub(/^([A-Za-z]:)/, '') # strip drive letter on Windows
      @software = software
    end

    # The path to the full install_dir cache for the project
    def cache_path
      File.join(Config.git_cache_dir, @install_dir)
    end

    # Whether the cache_path above exists
    def cache_path_exists?
      File.directory?(cache_path)
    end

    # Creates the full path if it does not exist already
    def create_cache_path
      FileUtils.mkdir_p(File.dirname(cache_path))
      shellout!("git --git-dir=#{cache_path} init -q") unless cache_path_exists?
      true
    end

    # Computes the tag for this cache entry
    def tag
      # Accumulate an array of all the software projects that come before
      # the name and version we are tagging. So if you have
      #
      # build_order = [ 1, 2, 3, 4, 5 ]
      #
      # And we are tagging 3, you would get dep_list = [ 1, 2 ]
      dep_list = @software.project.library.build_order.take_while do |dep|
        if dep.name == @software.name && dep.version == @software.version
          false
        else
          true
        end
      end

      # This is the list of all the unqiue shasums of all the software build
      # dependencies, including the on currently being acted upon.
      shasums = [dep_list.map(&:shasum), @software.shasum].flatten
      suffix  = Digest::SHA256.hexdigest(shasums.join('|'))

      "#{@software.name}-#{suffix}"
    end

    # Create an incremental install path cache for the software step
    def incremental
      create_cache_path
      shellout!(%Q(git --git-dir=#{cache_path} --work-tree=#{@install_dir} add -A -f))
      begin
        shellout!(%Q(git --git-dir=#{cache_path} --work-tree=#{@install_dir} commit -q -m "Backup of #{tag}"))
      rescue Mixlib::ShellOut::ShellCommandFailed => e
        if e.message !~ /nothing to commit/
          raise
        end
      end
      shellout!(%Q(git --git-dir=#{cache_path} --work-tree=#{@install_dir} tag -f "#{tag}"))
    end

    def restore
      create_cache_path
      cmd = shellout(%Q(git --git-dir=#{cache_path} --work-tree=#{@install_dir} tag -l "#{tag}"))

      restore_me = false
      cmd.stdout.each_line do |line|
        restore_me = true if tag == line.chomp
      end

      if restore_me
        shellout!(%Q(git --git-dir=#{cache_path} --work-tree=#{@install_dir} checkout -f "#{tag}"))
        true
      else
        false
      end
    end
  end
end
