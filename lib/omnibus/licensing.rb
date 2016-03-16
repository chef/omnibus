#
# Copyright 2015 Chef Software, Inc.
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

require 'uri'
require 'fileutils'
require 'omnibus/download_helpers'

module Omnibus
  class Licensing
    include Logging
    include DownloadHelpers

    OUTPUT_DIRECTORY = "LICENSES".freeze

    class << self
      # @see (Licensing#create!)
      def create!(project)
        new(project).create!
      end
    end

    #
    # The project to create licenses for.
    #
    # @return [Project]
    #
    attr_reader :project

    #
    # @param [Project] project
    #   the project to create licenses for.
    #
    def initialize(project)
      @project = project
    end

    #
    # Creates the license files for given project.
    # It is assumed that the project has already been built.
    #
    # @return [void]
    #
    def create!
      prepare
      create_software_license_files
      create_project_license_file
    end

    #
    # Creates the required directories for licenses.
    #
    # @return [void]
    #
    def prepare
      FileUtils.rm_rf(output_dir)
      FileUtils.mkdir_p(output_dir)
    end

    #
    # Creates the top level license file for the project.
    # Top level file is created at #{project.license_file_path}
    # and contains the name of the project, version of the project,
    # text of the license of the project and a summary of the licenses
    # of the included software components.
    #
    # @return [void]
    #
    def create_project_license_file
      File.open(project.license_file_path, 'w') do |f|
        f.puts "#{project.name} #{project.build_version} license: \"#{project.license}\""
        f.puts ""
        f.puts project_license_content
        f.puts ""
        f.puts components_license_summary
      end
    end

    #
    # Copies the license files specified by the software components into the
    # output directory.
    #
    # @return [void]
    #
    def create_software_license_files
      license_map.each do |name, values|
        license_files = values[:license_files]

        license_files.each do |license_file|
          if license_file
            output_file = license_package_location(name, license_file)

            if local?(license_file)
              input_file = File.expand_path(license_file, values[:project_dir])
              if File.exist?(input_file)
                FileUtils.cp(input_file, output_file)
              else
                licensing_warning("License file '#{input_file}' does not exist for software '#{name}'.")
              end
            else
              begin
                download_file!(license_file, output_file, enable_progress_bar: false)
              rescue SocketError,
                     Errno::ECONNREFUSED,
                     Errno::ECONNRESET,
                     Errno::ENETUNREACH,
                     Timeout::Error,
                     OpenURI::HTTPError
                licensing_warning("Can not download license file '#{license_file}' for software '#{name}'.")
              end
            end
          end
        end
      end
    end

    #
    # Contents of the project's license
    #
    # @return [String]
    #
    def project_license_content
      project.license_file.nil? ? "" : IO.read(File.join(Config.project_root,project.license_file))
    end

    #
    # Summary of the licenses included by the softwares of the project.
    # It is in the form of:
    # ...
    # This product bundles python 2.7.9,
    # which is available under a "Python" License.
    # For details, see:
    # /opt/opscode/LICENSES/python-LICENSE
    # ...
    #
    # @return [String]
    #
    def components_license_summary
      out = "\n\n"

      license_map.keys.sort.each do |name|
        license = license_map[name][:license]
        license_files = license_map[name][:license_files]
        version = license_map[name][:version]

        out << "This product bundles #{name} #{version},\n"
        out << "which is available under a \"#{license}\" License.\n"
        if !license_files.empty?
          out << "For details, see:\n"
          license_files.each do |license_file|
            out << "#{license_package_location(name, license_file)}\n"
          end
        end
        out << "\n"
      end

      out
    end

    #
    # Map that collects information about the licenses of the softwares
    # included in the project.
    #
    # @example
    # {
    #   ...
    #   "python" => {
    #     "license" => "Python",
    #     "license_files" => "LICENSE",
    #     "version" => "2.7.9",
    #     "project_dir" => "/var/cache/omnibus/src/python/Python-2.7.9/"
    #   },
    #   ...
    # }
    #
    # @return [Hash]
    #
    def license_map
      @license_map ||= begin
        map = {}

        project.library.each do |component|
          # Some of the components do not bundle any software but contain
          # some logic that we use during the build. These components are
          # covered under the project's license and they do not need specific
          # license files.
          next if component.license == :project_license

          map[component.name] = {
            license: component.license,
            license_files: component.license_files,
            version: component.version,
            project_dir: component.project_dir,
          }
        end

        map
      end
    end

    #
    # Returns the location where the license file should reside in the package.
    # License file is named as <project_name>-<license_file_name> and created
    # under the output licenses directory.
    #
    # @return [String]
    #
    def license_package_location(component_name, where)
      if local?(where)
        File.join(output_dir, "#{component_name}-#{File.split(where).last}")
      else
        u = URI(where)
        File.join(output_dir, "#{component_name}-#{File.basename(u.path)}")
      end
    end

    #
    # Output directory to create the licenses in.
    #
    # @return [String]
    #
    def output_dir
      File.expand_path(OUTPUT_DIRECTORY, project.install_dir)
    end

    #
    # Returns if the given path to a license is local or a remote url.
    #
    # @return [Boolean]
    #
    def local?(license)
      u = URI(license)
      return u.scheme.nil?
    end

    #
    # Logs the given message as warning.
    #
    # @param [String] message
    #   message to log as warning
    def licensing_warning(message)
      log.warn(log_key) { message }
    end
  end
end
