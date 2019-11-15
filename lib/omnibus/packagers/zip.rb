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

require "pathname"
require "omnibus/packagers/windows_base"
require "fileutils"

module Omnibus
  class Packager::ZIP < Packager::WindowsBase
    id :zip

    setup do
    end

    build do
      if signing_identity or signing_identity_file
        puts "starting signing"
        if additional_sign_files
            additional_sign_files.each do |signfile|
            puts "signing #{signfile}"
            sign_package(signfile)
            end
        end

      end
      # If there are extra package files let's add them
      zip_source_path = ""
      
      if not extra_package_dir.nil?
        if File.directory?(extra_package_dir)
          # Let's collect the DirectoryRefs
          zip_source_path = "#{windows_safe_path(extra_package_dir)}\\* "
        end
      end
      zip_file = windows_safe_path(Config.package_dir, zip_name)
      zip_source_path += "#{windows_safe_path(project.install_dir)}\\*"
      cmd = <<-EOH.split.join(" ").squeeze(" ").strip
      7z a -r
      #{zip_file}
      #{zip_source_path}
      EOH
      shellout!(cmd)

    end

    #
    # @!group DSL methods
    # --------------------------------------------------

    #
    # set or retrieve additional files to sign
    #
    def additional_sign_files(val = NULL)
      if null?(val)
        @additional_sign_files
      else 
        unless val.is_a?(Array)
          raise InvalidValue.new(:additional_sign_files, "be an Array")
        end
        @additional_sign_files = val
      end
    end
    expose :additional_sign_files

    def extra_package_dir(val = NULL)
      if null?(val)
        @extra_package_dir || nil
      else
        unless val.is_a?(String)
          raise InvalidValue.new(:extra_package_dir, "be a String")
        end
        @extra_package_dir = val
      end
    end
    expose :extra_package_dir

    #
    # Discovers a path to a gem/file included in a gem under the install directory.
    #
    # @example
    #   gem_path 'chef-[0-9]*-mingw32' -> 'some/path/to/gems/chef-version-mingw32'
    #
    # @param [String] glob
    #   a ruby acceptable glob path such as with **, *, [] etc.
    #
    # @return [String] path relative to the project's install_dir
    #
    # Raises exception the glob matches 0 or more than 1 file/directory.
    #
    def gem_path(glob = NULL)
      unless glob.is_a?(String) || null?(glob)
        raise InvalidValue.new(:glob, "be an String")
      end

      install_path = Pathname.new(project.install_dir)

      # Find path in which the Chef gem is installed
      search_pattern = install_path.join("**", "gems")
      search_pattern = search_pattern.join(glob) unless null?(glob)
      file_paths = Pathname.glob(search_pattern).find

      raise "Could not find `#{search_pattern}'!" if file_paths.none?
      raise "Multiple possible matches of `#{search_pattern}'! : #{file_paths}" if file_paths.count > 1
      file_paths.first.relative_path_from(install_path).to_s
    end
    expose :gem_path

    #
    # @!endgroup
    # --------------------------------------------------

    # @see Base#package_name
    def package_name
      zip_name
    end

    def zip_name
      "#{project.package_name}-#{project.build_version}-#{project.build_iteration}-#{Config.windows_arch}.zip"
    end

    
    #
    # The path where the MSI resources will live.
    #
    # @return [String]
    #
    def resources_dir
      File.expand_path("#{staging_dir}/Resources")
    end

    

    #
    # Get the shell command to create a zip file that contains
    # the contents of the project install directory
    #
    # @return [String]
    #
    def zip_command
      <<-EOH.split.join(" ").squeeze(" ").strip
      7z a -r
      #{windows_safe_path(staging_dir)}\\#{project.name}.zip
      #{windows_safe_path(project.install_dir)}\\*
      EOH
    end

  end
end
