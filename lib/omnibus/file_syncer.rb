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

require "fileutils"

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
    #
    # @return [Array<String>]
    #   the list of all files
    #
    def all_files_under(source, options = {})
      excludes = Array(options[:exclude]).map do |exclude|
        [exclude, "#{exclude}/*"]
      end.flatten

      source_files = glob(File.join(source, "**/*"))
      source_files = source_files.reject do |source_file|
        basename = relative_path_for(source_file, source)
        excludes.any? { |exclude| File.fnmatch?(exclude, basename, File::FNM_DOTMATCH) }
      end
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

      source_files = all_files_under(source, options)

      # Ensure the destination directory exists
      FileUtils.mkdir_p(destination) unless File.directory?(destination)

      # Copy over the filtered source files
      source_files.each do |source_file|
        relative_path = relative_path_for(source_file, source)

        # Create the parent directory
        parent = File.join(destination, File.dirname(relative_path))
        FileUtils.mkdir_p(parent) unless File.directory?(parent)

        case File.ftype(source_file).to_sym
        when :directory
          FileUtils.mkdir_p("#{destination}/#{relative_path}")
        when :link
          target = File.readlink(source_file)

          Dir.chdir(destination) do
            FileUtils.ln_sf(target, "#{destination}/#{relative_path}")
          end
        when :file
          source_stat = File.stat(source_file)
          # Detect 'files' which are hard links and use ln instead of cp to
          # duplicate them, provided their source is in place already
          if hardlink? source_stat
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
          else
            # First attempt a regular copy. If we don't have write
            # permission on the File, open will probably fail with
            # EACCES (making it hard to sync files with permission
            # r--r--r--). Rescue this error and use cp_r's
            # :remove_destination option.
            begin
              FileUtils.cp(source_file, "#{destination}/#{relative_path}")
            rescue Errno::EACCES
              FileUtils.cp_r(source_file, "#{destination}/#{relative_path}", remove_destination: true)
            end
          end
        else
          raise RuntimeError,
            "Unknown file type: `File.ftype(source_file)' at `#{source_file}'!"
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

    private

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
