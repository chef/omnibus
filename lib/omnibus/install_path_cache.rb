#
# Copyright:: Copyright (c) 2014 Chef Software, Inc.
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

require 'omnibus/util'
require 'omnibus/config'
require 'fileutils'
require 'digest'

module Omnibus
  class InstallPathCache
    include Util

    def initialize(install_path, software)
      @install_path = install_path
      @software = software
    end

    # The path to the full install_path cache for the project
    def cache_path
      File.join(Omnibus::Config.install_path_cache_dir, @install_path)
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
      name = @software.name
      version = @software.version

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
      dep_string = dep_list.map { |i| "#{i.name}-#{i.version}" }.join('-')
      # digest the content of the software's config so that changes to
      # build params invalidate cache.
      dep_string = IO.read(@software.source_config) + dep_string
      digest = Digest::SHA256.hexdigest(dep_string)
      "#{name}-#{version}-#{digest}"
    end

    # Create an incremental install path cache for the software step
    def incremental
      create_cache_path
      shellout!("git --git-dir=#{cache_path} --work-tree=#{@install_path} add -A -f")
      begin
        shellout!("git --git-dir=#{cache_path} --work-tree=#{@install_path} commit -q -m 'Backup of #{tag}'")
      rescue Mixlib::ShellOut::ShellCommandFailed => e
        if e.message !~ /nothing to commit/
          raise
        end
      end
      shellout!("git --git-dir=#{cache_path} --work-tree=#{@install_path} tag -f '#{tag}'")
    end

    def restore
      create_cache_path
      cmd = shellout("git --git-dir=#{cache_path} --work-tree=#{@install_path} tag -l #{tag}")

      restore_me = false
      cmd.stdout.each_line do |line|
        restore_me = true if tag == line.chomp
      end

      if restore_me
        shellout!("git --git-dir=#{cache_path} --work-tree=#{@install_path} checkout -f '#{tag}'")
        true
      else
        false
      end
    end
  end
end
