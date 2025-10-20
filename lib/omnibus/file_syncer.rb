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

require "fileutils" unless defined?(FileUtils)
require "omnibus/thread_pool"

module Omnibus
  module FileSyncer
    extend self

    # Files to be ignored during a directory globbing
    IGNORED_FILES = %w{. ..}.freeze

    #
    # Glob across the given pattern, accounting for dotfiles, removing Ruby's
    # dumb idea to include +'.'+ and +'..'+ as entries.
    #
    # @param [String] pattern
    #   the path or glob pattern to get all files from
    #
    # @return [Array<String>]
    #   the list of all files
    #
    def glob(pattern)
      pattern = Pathname.new(pattern).cleanpath.to_s
      Dir.glob(pattern, File::FNM_DOTMATCH).sort.reject do |file|
        basename = File.basename(file)
        IGNORED_FILES.include?(basename)
      end
    end

    #
    # Glob for all files under a given path/pattern, removing Ruby's
    # dumb idea to include +'.'+ and +'..'+ as entries.
    #
    # @param [String] source
    #   the path or glob pattern to get all files from
    #
    # @option options [String, Array<String>] :exclude
    #   a file, folder, or globbing pattern of files to ignore when syncing
    # @option options [String, Array<String>] :include
    #   a file, folder, or globbing pattern of files that has to be matched
    #   when syncing
    #
    # @return [Array<String>]
    #   the list of all files
    #
    def all_files_under(source, options = {})
      excludes = Array(options[:exclude]).map do |exclude|
        [exclude, "#{exclude}/**"]
      end.flatten

      includes = Array(options[:include]).map do |include|
        [include, "#{include}/**"]
      end.flatten

      source_files = glob(File.join(source, "**/*"))
      source_files = source_files.reject do |source_file|
        basename = relative_path_for(source_file, source)
        excludes.any? { |exclude| File.fnmatch?(exclude, basename, File::FNM_DOTMATCH | File::FNM_PATHNAME) }
      end

      if not includes.empty?
        source_files = source_files.reject do |source_file|
          basename = relative_path_for(source_file, source)
          # File::FNM_PATHNAME Prohibit wildcards from matching a slash ('/')
          # which means includes.none? will return true when the path includes a '/':
          #
          #   File.fnmatch?(".debug"), .debug/opt, File::FNM_DOTMATCH | File::FNM_PATHNAME) = false
          #   File.fnmatch?(".debug/**"), .debug/opt, File::FNM_DOTMATCH | File::FNM_PATHNAME) = true
          #   includes.none? { |include| File.fnmatch?(include), .debug/opt, File::FNM_DOTMATCH | File::FNM_PATHNAME) } = false
          #
          #   File.fnmatch?(".debug"), .debug/opt/datadog-agent, File::FNM_DOTMATCH | File::FNM_PATHNAME) = false
          #   File.fnmatch?(".debug/**"), .debug/opt/datadog-agent, File::FNM_DOTMATCH | File::FNM_PATHNAME) = false
          #   includes.none? { |include| File.fnmatch?(include), .debug/opt/datadog-agent, File::FNM_DOTMATCH | File::FNM_PATHNAME) } = true
          #
          # As per above, we can see that it would not include any subfolder beneath the fist level of nesting.
          includes.none? { |include| File.fnmatch?(include, basename, File::FNM_DOTMATCH) }
        end
      end

      source_files
    end

    #
    # Copy the files from +source+ to +destination+, while removing any files
    # in +destination+ that are not present in +source+.
    #
    # The method accepts an optional +:exclude+ parameter to ignore files and
    # folders that match the given pattern(s). Note the exclude pattern behaves
    # on paths relative to the given source. If you want to exclude a nested
    # directory, you will need to use something like +**/directory+.
    #
    # @raise ArgumentError
    #   if the +source+ parameter is not a directory
    #
    # @param [String] source
    #   the path on disk to sync from
    # @param [String] destination
    #   the path on disk to sync to
    #
    # @option options [String, Array<String>] :exclude
    #   a file, folder, or globbing pattern of files to ignore when syncing
    #
    # @return [true]
    #
    def sync(source, destination, options = {})
      unless File.directory?(source)
        raise ArgumentError, "`source' must be a directory, but was a " \
          "`#{File.ftype(source)}'! If you just want to sync a file, use " \
          "the `copy' method instead."
      end

      # Collect source files
      source_files = all_files_under(source, options)

      # Clear any hardlink that we might have seen while syncing a previous directory
      # This can happen when generating 2 different packages in a row
      hardlink_sources.clear

      # First gather all the directories and their permissions
      dir_mode_map = {}
      dir_mode_map[destination] = File.stat(source).mode
      source_files.each do |source_file|
        relative_path = relative_path_for(source_file, source)
        # Add source itself if it's a directory
        if File.ftype(source_file) == "directory"
          dest_target = File.join(destination, relative_path)
          unless dir_mode_map.key?(dest_target)
            dir_mode_map[dest_target] = File.stat(source_file).mode
          end
        end
        # Add parent
        dirname = File.dirname(relative_path)
        dest_dir = File.join(destination, dirname)
        unless dir_mode_map.key?(dest_dir)
          src_dir = File.join(source, dirname)
          dir_mode_map[dest_dir] = File.stat(src_dir).mode
        end
      end

      # Create directories sorted by depth (shallowest first) to ensure correct permissions
      dir_mode_map.sort_by { |path, _| path.count(File::SEPARATOR) }.each do |dest_dir, mode|
        FileUtils.mkdir_p(dest_dir, :mode => mode)
      end

      # Categorize files for processing
      regular_files = []
      symlinks = []
      hardlinks = []

      source_files.each do |source_file|
        case File.ftype(source_file).to_sym
        when :directory
          # Skip - already created
        when :link
          symlinks << source_file
        when :file
          source_stat = File.stat(source_file)
          if hardlink?(source_stat)
            hardlinks << [source_file, source_stat]
          else
            regular_files << source_file
          end
        else
          raise RuntimeError,
                "Unknown file type: `File.ftype(source_file)' at `#{source_file}'!"
        end
      end

      # Process regular files and symlinks in parallel
      parallel_items = regular_files + symlinks
      thread_count = [8, parallel_items.size].min

      if parallel_items.any?
        ThreadPool.new(thread_count) do |pool|
          regular_files.each do |source_file|
            pool.schedule do
              relative_path = relative_path_for(source_file, source)
              begin
                FileUtils.cp(source_file, "#{destination}/#{relative_path}")
              rescue Errno::EACCES
                FileUtils.cp_r(source_file, "#{destination}/#{relative_path}", remove_destination: true)
              end
            end
          end

          symlinks.each do |source_file|
            pool.schedule do
              relative_path = relative_path_for(source_file, source)
              target = File.readlink(source_file)
              FileUtils.ln_sf(target, "#{destination}/#{relative_path}")
            end
          end
        end
      end

      # Process hardlinks serially (to maintain hardlink relationships)
      hardlinks.each do |source_file, source_stat|
        relative_path = relative_path_for(source_file, source)
        if existing = hardlink_sources[[source_stat.dev, source_stat.ino]]
          FileUtils.ln(existing, "#{destination}/#{relative_path}", force: true)
        else
          begin
            FileUtils.cp(source_file, "#{destination}/#{relative_path}")
          rescue Errno::EACCES
            FileUtils.cp_r(source_file, "#{destination}/#{relative_path}", remove_destination: true)
          end
          hardlink_sources.store([source_stat.dev, source_stat.ino], "#{destination}/#{relative_path}")
        end
      end

      # Remove any files in the destination that are not in the source files
      destination_files = glob("#{destination}/**/*")

      # Calculate the relative paths of files so we can compare to the
      # source.
      relative_source_files = source_files.map do |file|
        relative_path_for(file, source)
      end
      relative_destination_files = destination_files.map do |file|
        relative_path_for(file, destination)
      end

      # Remove any extra files that are present in the destination, but are
      # not in the source list
      extra_files = relative_destination_files - relative_source_files
      extra_files.each do |file|
        FileUtils.rm_rf(File.join(destination, file))
      end

      true
    end

    #
    # The relative path of the given +path+ to the +parent+.
    #
    # @param [String] path
    #   the path to get relative with
    # @param [String] parent
    #   the parent where the path is contained (hopefully)
    #
    # @return [String]
    #
    def relative_path_for(path, parent)
      Pathname.new(path).relative_path_from(Pathname.new(parent)).to_s
    end

    private

    #
    # A list of hard link file(s) sources which have already been copied,
    # indexed by device and inode number.
    #
    # @api private
    #
    # @return [Hash{Array<FixNum, FixNum> => String}]
    #
    def hardlink_sources
      @hardlink_sources ||= {}
    end

    #
    # Determines whether or not a file is a hardlink.
    #
    # @param [File::Stat] stat
    #   the File::Stat object for a file you wand to test
    #
    # @return [true, false]
    #
    def hardlink?(stat)
      case stat.ftype.to_sym
      when :file
        stat.nlink > 1
      else
        false
      end
    end
  end
end
