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

require "digest"
require "fileutils"

module Omnibus
  class GitCache
    include Util
    include Logging

    # The serial number represents compatibility of a cache entry with the
    # current version of the omnibus code base. Any time a change is made to
    # omnibus that makes the code incompatible with any cache entries created
    # before the code change, the serial number should be incremented.
    #
    # For example, if a code change generates content in the `install_dir`
    # before cache snapshots are taken, any snapshots created before upgrade
    # will not have the generated content, so these snapshots would be
    # incompatible with the current omnibus codebase. Incrementing the serial
    # number ensures these old shapshots will not be used in subsequent builds.
    SERIAL_NUMBER = 1

    REQUIRED_GIT_FILES = %w{
      HEAD
      description
      hooks
      info
      objects
      refs
    }.freeze

    #
    # @return [Software]
    #
    attr_reader :software

    #
    # @param [Software] software
    #   the software this git cache is for
    #
    def initialize(software)
      @software = software
    end

    #
    # The path to the full install_dir cache for the project.
    #
    # @return [String]
    #
    def cache_path
      @cache_path ||= File.join(Config.git_cache_dir, install_dir)
    end

    #
    # Creates the full path if it does not exist already.
    #
    # @return [true, false]
    #   true if the path was created, false otherwise
    #
    def create_cache_path
      if File.directory?(cache_path)
        false
      else
        create_directory(File.dirname(cache_path))
        git_cmd("init -q")
        true
      end
    end

    #
    # Computes the tag for this cache entry.
    #
    # @return [String]
    #
    def tag
      return @tag if @tag

      log.internal(log_key) { "Calculating tag" }

      # Accumulate an array of all the software projects that come before
      # the name and version we are tagging. So if you have
      #
      # build_order = [ 1, 2, 3, 4, 5 ]
      #
      # And we are tagging 3, you would get dep_list = [ 1, 2 ]
      dep_list = software.project.library.build_order.take_while do |dep|
        if dep.name == software.name && dep.version == software.version
          false
        else
          true
        end
      end

      log.internal(log_key) { "dep_list: #{dep_list.map(&:name).inspect}" }

      # This is the list of all the unqiue shasums of all the software build
      # dependencies, including the on currently being acted upon.
      shasums = [dep_list.map(&:shasum), software.shasum].flatten
      suffix  = Digest::SHA256.hexdigest(shasums.join("|"))
      @tag    = "#{software.name}-#{suffix}-#{SERIAL_NUMBER}"

      log.internal(log_key) { "tag: #{@tag}" }

      @tag
    end

    # Create an incremental install path cache for the software step
    def incremental
      log.internal(log_key) { "Performing incremental cache" }

      create_cache_path
      remove_git_dirs

      git_cmd("add -A -f")

      begin
        git_cmd(%Q{commit -q -m "Backup of #{tag}"})
      rescue CommandFailed => e
        raise unless e.message.include?("nothing to commit")
      end

      git_cmd(%Q{tag -f "#{tag}"})
    end

    def restore
      log.internal(log_key) { "Performing cache restoration" }

      create_cache_path

      restore_me = false
      cmd = git_cmd(%Q{tag -l "#{tag}"})

      cmd.stdout.each_line do |line|
        restore_me = true if tag == line.chomp
      end

      if restore_me
        log.internal(log_key) { "Detected tag `#{tag}' can be restored, restoring" }
        git_cmd(%Q{checkout -f "#{tag}"})
        true
      else
        log.internal(log_key) { "Could not find tag `#{tag}', skipping restore" }
        false
      end
    end

    #
    # Git caching will attempt to version embedded git directories, partially
    # versioning them. This causes failures on subsequent runs. This method
    # will find git directories and remove them to prevent those errors.
    #
    # @return [true]
    def remove_git_dirs
      log.internal(log_key) { "Removing git directories" }

      Dir.glob("#{install_dir}/**/{,.*}/config").reject do |path|
        REQUIRED_GIT_FILES.any? do |required_file|
          !File.exist?(File.join(File.dirname(path), required_file))
        end
      end.each do |path|
        log.internal(log_key) { "Removing git dir `#{path}'" }
        FileUtils.rm_rf(File.dirname(path))
      end

      true
    end

    private

    #
    # Shell out and invoke a git command in the context of the git cache.
    #
    # We explicitly disable autocrlf because we want bit-for-bit storage and
    # recovery of build output. Hashes calculated on output files will be
    # invalid if we muck around with files after they have been produced.
    #
    # @return [Mixlib::Shellout] the underlying command object.
    #
    def git_cmd(command)
      shellout!("git -c core.autocrlf=false --git-dir=#{cache_path} --work-tree=#{install_dir} #{command}")
    end

    #
    #
    # The installation directory for this software's project. Drive letters are
    # stripped for Windows.
    #
    # @return [String]
    #
    def install_dir
      @install_dir ||= software.project.install_dir.sub(/^([A-Za-z]:)/, "")
    end

    # Override the log_key for this class to include the software name
    #
    # @return [String]
    def log_key
      @log_key ||= "#{super}: #{software.name}"
    end
  end
end
