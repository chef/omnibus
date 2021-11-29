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

require "csv"
require "uri"
require "fileutils"
require "omnibus/download_helpers"
require "license_scout/collector"
require "license_scout/options"

module Omnibus
  class Licensing
    include Logging
    include DownloadHelpers
    include Sugarable

    OUTPUT_DIRECTORY = "LICENSES".freeze
    CACHE_DIRECTORY = "license-cache".freeze

    class << self
      # Creates a new instance of Licensing, executes preparation steps, then
      # yields control to a given block, and then creates a summary of the
      # included licenses.
      #
      # @example Building a project:
      #
      #   Licensing.create_incrementally(self) do |license_collector|
      #     softwares.each do |software|
      #       software.build_me([license_collector])
      #     end
      #   end
      #
      # @param [Project] project
      #   The project being built.
      #
      # @yieldparam [Licensing] license_collector
      #   Yields an instance of Licensing. Call #execute_post_build to copy the
      #   license files for a Software definition.
      #
      # @return [Licensing]
      #
      def create_incrementally(project)
        new(project).tap do |license_collector|
          license_collector.prepare
          license_collector.validate_license_info

          yield license_collector

          license_collector.process_transitive_dependency_licensing_info
          license_collector.create_project_license_file
          license_collector.third_party_licenses_collector
          license_collector.raise_if_warnings_fatal!
        end
      end
    end

    #
    # The project to create licenses for.
    #
    # @return [Project]
    #
    attr_reader :project

    #
    # The warnings encountered while preparing the licensing information
    #
    # @return [Array<String>]
    #
    attr_reader :licensing_warnings

    #
    # The warnings encountered while preparing the licensing information for
    # transitive dependencies.
    #
    # @return [Array<String>]
    #
    attr_reader :transitive_dependency_licensing_warnings

    #
    # Manifest data of transitive dependency licensing information
    #
    # @return Hash
    #
    attr_reader :dep_license_map

    #
    # @param [Project] project
    #   the project to create licenses for.
    #
    def initialize(project)
      @project = project
      @licensing_warnings = []
      @transitive_dependency_licensing_warnings = []
      @dep_license_map = {}
    end

    #
    # Creates the required directories for licenses.
    #
    # @return [void]
    #
    def prepare
      FileUtils.rm_rf(output_dir)
      FileUtils.mkdir_p(output_dir)
      FileUtils.touch(output_dir_gitkeep_file)
      FileUtils.rm_rf(cache_dir)
      FileUtils.mkdir_p(cache_dir)
      FileUtils.touch(cache_dir_gitkeep_file)
    end

    # Required callback to use instances of this class as a build wrapper for
    # Software#build_me. Licensing doesn't need to do anything pre-build, so
    # this does nothing.
    #
    # @param [Software] software
    #
    # @return [void]
    #
    def execute_pre_build(software)
    end

    # Callback that gets called by Software#build_me after the build is done.
    # Invokes license copying for the given software. This ensures that
    # licenses are copied before a git cache snapshot is taken, so that the
    # license files are correctly restored when a build is skipped due to a
    # cache hit.
    #
    # @param [Software] software
    #
    # @return [void]
    #
    def execute_post_build(software)
      collect_licenses_for(software)

      unless software.skip_transitive_dependency_licensing
        collect_transitive_dependency_licenses_for(software)
      end
    end

    #
    # Inspects the licensing information for the project and the included
    # software components. Logs the found issues to the log as warning.
    #
    # @return [void]
    #
    def validate_license_info
      # First check the project licensing information

      # Check existence of licensing information
      if project.license == "Unspecified"
        licensing_warning("Project '#{project.name}' does not contain licensing information.")
      end

      # Check license file exists or project license is standard
      if project.license != "Unspecified" && !STANDARD_LICENSES.keys.include?(project.license) && project.license_file.nil?
        licensing_warning("Project '#{project.name}' does not point to a license file and its license is not standard (#{project.license}).")
      end

      # Check used license is a standard license
      if project.license != "Unspecified" && !STANDARD_LICENSES.keys.include?(project.license)
        licensing_info("Project '#{project.name}' is using '#{project.license}' which is not one of the standard licenses identified in https://opensource.org/licenses/alphabetical. Consider using one of the standard licenses.")
      end

      # Now let's check the licensing info for software components
      license_map.each do |software_name, license_info|
        # First check if the software specified a license
        if license_info[:license] == "Unspecified"
          licensing_warning("Software '#{software_name}' does not contain licensing information.")
        end

        # Check if the software specifies any license files or if it's a standard license
        if license_info[:license] != "Unspecified" && !STANDARD_LICENSES.keys.include?(license_info[:license]) && license_info[:license_files].empty?
          licensing_warning("Software '#{software_name}' does not point to any license files and its license is not standard (#{license_info[:license]}).")
        end

        # Check if the software license is one of the standard licenses
        if license_info[:license] != "Unspecified" && !STANDARD_LICENSES.keys.include?(license_info[:license])
          licensing_info("Software '#{software_name}' uses license '#{license_info[:license]}' which is not one of the standard licenses identified in https://opensource.org/licenses/alphabetical. Consider using one of the standard licenses.")
        end
      end
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
      File.open(project.license_file_path, "w") do |f|
        f.puts "#{project.name} #{project.build_version} license: \"#{project.license}\""
        f.puts ""
        f.puts project_license_content
        f.puts ""
        f.puts components_license_summary
        f.puts ""
        f.puts dependencies_license_summary
        f.puts ""
        f.puts third_party_license_summary
      end
    end

    #
    # Contents of the project's license
    #
    # @return [String]
    #
    def project_license_content
      project.license_file.nil? ? "" : IO.read(File.join(Config.project_root, project.license_file))
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
    # Summary of the third party licenses included in the project.
    # It is in the form of:
    # ...
    # This product bundles a third-party transitive dependency code.cloudfoundry.org/garden,
    # which is available under a "Apache-2.0" License.
    # ...
    #
    # @return [String]
    #
    def third_party_license_summary
      out = "\n\n"

      third_party_license_map.keys.sort.each do |name|
        license = third_party_license_map[name][:license]

        out << "This product bundles the third-party transitive dependency #{name},\n"
        out << "which is available under a \"#{license}\" License.\n"
        out << "\n"
      end

      out
    end

    #
    # Summary of the licenses of the transitive dependencies of the project.
    # It is in the form of:
    # ...
    # This product includes inifile 3.0.0
    # which is a 'ruby_bundler' dependency of 'chef',
    # and which is available under a 'MIT' License.
    # For details, see:
    # /opt/opscode/LICENSES/ruby_bundler-inifile-3.0.0-README.md
    # ...
    #
    # @return [String]
    #
    def dependencies_license_summary
      out = "\n\n"

      dep_license_map.each do |dep_mgr_name, data|
        data.each do |dep_name, data|
          data.each do |dep_version, dep_data|
            projects = dep_data["dependency_of"].sort.map { |p| "'#{p}'" }.join(", ")
            files = dep_data["license_files"].map { |f| File.join(output_dir, f) }

            out << "This product includes #{dep_name} #{dep_version}\n"
            out << "which is a '#{dep_mgr_name}' dependency of #{projects},\n"
            out << "and which is available under a '#{dep_data["license"]}' License.\n"
            out << "For details, see:\n"
            out << files.join("\n")
            out << "\n\n"
          end
        end
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

          license_files = component.license_files
          # If the license is a standard license, use the STANDARD_LICENSES URL associated with it
          if component.license_files.empty? && STANDARD_LICENSES.keys.include?(component.license)
            license_files = [STANDARD_LICENSES[component.license]]
          end

          map[component.name] = {
            license: component.license,
            license_files: license_files,
            version: component.version,
            project_dir: component.project_dir,
          }
        end

        map
      end
    end

    #
    # Map that collects information about the third party licenses of the
    # softwares included in the project.
    #
    # @example
    # {
    #   ...
    #   "python" => {
    #     "license" => "Python",
    #     "license_files" => nil,
    #     "version" => nil,
    #     "project_dir" => nil
    #   },
    #   ...
    # }
    #
    # @return [Hash]
    #
    def third_party_license_map
      @third_party_license_map ||= begin
        map = {}

        if project.third_party_licenses && project.third_party_licenses != "Unspecified"
          license_table = CSV.parse(File.read(project.third_party_licenses), headers: true)
          license_table.each do |lic|
            map[lic["Origin"]] = {
              license: lic["License"],
              license_files: nil,
              version: nil,
              project_dir: nil,
            }
          end
        end

        map
      end
    end

    #
    # Function that pulls the third party licenses defined for the project, then fetches
    # them and drops them into the project output directory.
    #
    def third_party_licenses_collector
      licenses = {}

      if project.third_party_licenses && project.third_party_licenses != "Unspecified"
        license_table = CSV.parse(File.read(project.third_party_licenses), headers: true)
        license_table.each do |lic|
          unless licenses.key?(lic["License"])
            licenses[lic["License"]] = STANDARD_LICENSES[lic["License"]]
          end
        end

        licenses.each do |name, url|
          if url.nil?
            licensing_warning("Unknown standard license for software '#{name}'.")
            next
          end
          output_file = license_package_location("THIRD-PARTY", name)
          begin
            download_file!(url, output_file, enable_progress_bar: false)
            File.chmod 0644, output_file unless windows?
          rescue SocketError,
                 Errno::ECONNREFUSED,
                 Errno::ECONNRESET,
                 Errno::ENETUNREACH,
                 Timeout::Error,
                 OpenURI::HTTPError,
                 OpenSSL::SSL::SSLError
            licensing_warning("Can not download license file '#{url}' for software '#{software_name}'.")
            # If we got here, we need to fail now so we don't take a git
            # cache snapshot, or else the software build could be restored
            # from cache without fixing the license issue.
            raise_if_warnings_fatal!
          end
        end
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
    # Path to a .gitkeep file we create in the output dir so git caching
    # doesn't delete the directory.
    #
    # @return [String]
    #
    def output_dir_gitkeep_file
      File.join(output_dir, ".gitkeep")
    end

    # Cache directory where transitive dependency licenses will be collected in.
    #
    # @return [String]
    #
    def cache_dir
      File.expand_path(CACHE_DIRECTORY, project.install_dir)
    end

    #
    # Path to a .gitkeep file we create in the cache dir so git caching
    # doesn't delete the directory.
    #
    # @return [String]
    #
    def cache_dir_gitkeep_file
      File.join(cache_dir, ".gitkeep")
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
    # Logs the given message as info.
    #
    # This method should only be used for detecting in a license is known or not.
    # In the future, we will introduce a configurable way to whitelist or blacklist
    # the allowed licenses. Once we implement that we need to stop using this method.
    #
    # @param [String] message
    #   message to log as warning
    def licensing_info(message)
      log.info(log_key) { message }
    end

    #
    # Logs the given message as warning or fails the build depending on the
    # :fatal_licensing_warnings configuration setting.
    #
    # @param [String] message
    #   message to log as warning
    def licensing_warning(message)
      licensing_warnings << message
      log.warn(log_key) { message }
    end

    #
    # Logs the given message as warning or fails the build depending on the
    # :fatal_transitive_dependency_licensing_warnings configuration setting.
    #
    # @param [String] message
    #   message to log as warning
    def transitive_dependency_licensing_warning(message)
      transitive_dependency_licensing_warnings << message
      log.warn(log_key) { message }
    end

    def raise_if_warnings_fatal!
      warnings_to_raise = []
      if Config.fatal_licensing_warnings && !licensing_warnings.empty?
        warnings_to_raise << licensing_warnings
      end

      if Config.fatal_transitive_dependency_licensing_warnings && !transitive_dependency_licensing_warnings.empty?
        warnings_to_raise << transitive_dependency_licensing_warnings
      end

      warnings_to_raise.flatten!
      raise LicensingError.new(warnings_to_raise) unless warnings_to_raise.empty?
    end

    # 1. Parse all the licensing information for all software from 'cache_dir'
    # 2. Merge and drop the duplicates
    # 3. Add these licenses to the main manifest, to be merged with the main
    # licensing information from software definitions.
    def process_transitive_dependency_licensing_info
      Dir.glob("#{cache_dir}/*/*-dependency-licenses.json").each do |license_manifest_path|
        license_manifest_data = FFI_Yajl::Parser.parse(File.read(license_manifest_path))
        project_name = license_manifest_data["project_name"]
        dependency_license_dir = File.dirname(license_manifest_path)

        license_manifest_data["dependency_managers"].each do |dep_mgr_name, dependencies|
          dep_license_map[dep_mgr_name] ||= {}

          dependencies.each do |dependency|
            # Copy dependency files
            dependency["license_files"].each do |f|
              license_path = File.join(dependency_license_dir, f)
              output_path = File.join(output_dir, f)
              FileUtils.cp(license_path, output_path)
            end

            dep_name = dependency["name"]
            dep_version = dependency["version"]

            # If we already have this dependency we do not need to add it again.
            if dep_license_map[dep_mgr_name][dep_name] && dep_license_map[dep_mgr_name][dep_name][dep_version]
              dep_license_map[dep_mgr_name][dep_name][dep_version]["dependency_of"] << project_name
            else
              dep_license_map[dep_mgr_name][dep_name] ||= {}
              dep_license_map[dep_mgr_name][dep_name][dep_version] = {
                "license" => dependency["license"],
                "license_files" => dependency["license_files"],
                "dependency_of" => [project_name],
              }
            end
          end
        end
      end

      FileUtils.rm_rf(cache_dir)
    end

    private

    # Uses license_scout to collect the licenses for transitive dependencies
    # into #{output_dir}/license-cache/#{software.name}
    def collect_transitive_dependency_licenses_for(software)
      # We collect the licenses of the transitive dependencies of this software
      # with LicenseScout. We place these files under
      # /opt/project-name/license-cache for them to be cached in git_cache. Once
      # the build completes we will process these license files but we need to
      # perform this step after build, before git_cache to be able to operate
      # correctly with the git_cache.
      license_output_dir = File.join(cache_dir, software.name)

      collector = LicenseScout::Collector.new(
        software.project.name,
        software.project_dir,
        license_output_dir,
        LicenseScout::Options.new(
          environment: software.with_embedded_path,
          ruby_bin: software.embedded_bin("ruby")
        )
      )

      begin
        collector.run
        collector.issue_report.each { |i| transitive_dependency_licensing_warning(i) }
      rescue LicenseScout::Exceptions::UnsupportedProjectType => e
        # Looks like this project is not supported by LicenseScout. Either the
        # language and the dependency manager used by the project is not
        # supported, or the software definition does not have any transitive
        # dependencies.  In the latter case software definition should set
        # 'skip_transitive_dependency_licensing' to 'true' to correct this
        # error.
        # rubocop:disable Layout/ClosingHeredocIndentation, Naming/HeredocDelimiterNaming, Layout/IndentHeredoc
        transitive_dependency_licensing_warning(<<~EOH)
Software '#{software.name}' is not supported project type for transitive \
dependency license collection. See https://github.com/chef/license_scout for \
the list of supported languages and dependency managers. If this project does \
not have any transitive dependencies, consider setting \
'skip_transitive_dependency_licensing' to 'true' in order to correct this error.
EOH
      rescue LicenseScout::Exceptions::Error => e
        transitive_dependency_licensing_warning(<<~EOH)
Can not automatically detect licensing information for '#{software.name}' using \
license_scout. Error is: '#{e}'
EOH
      rescue Exception => e
        transitive_dependency_licensing_warning(<<~EOH)
Unexpected error while running license_scout for '#{software.name}': '#{e}'
EOH
        # rubocop:enable Layout/ClosingHeredocIndentation, Naming/HeredocDelimiterNaming, Layout/IndentHeredoc
      end
    end

    # Collect the license files for the software.
    def collect_licenses_for(software)
      return nil if software.license == :project_license

      software_name = software.name
      license_data = license_map[software_name]
      license_files = license_data[:license_files]

      license_files.each do |license_file|
        if license_file
          output_file = license_package_location(software_name, license_file)

          if local?(license_file)
            input_file = File.expand_path(license_file, license_data[:project_dir])
            if File.exist?(input_file)
              FileUtils.cp(input_file, output_file)
              File.chmod 0644, output_file unless windows?
            else
              licensing_warning("License file '#{input_file}' does not exist for software '#{software_name}'.")
              # If we got here, we need to fail now so we don't take a git
              # cache snapshot, or else the software build could be restored
              # from cache without fixing the license issue.
              raise_if_warnings_fatal!
            end
          else
            begin
              download_file!(license_file, output_file, enable_progress_bar: false)
              File.chmod 0644, output_file unless windows?
            rescue SocketError,
                   Errno::ECONNREFUSED,
                   Errno::ECONNRESET,
                   Errno::ENETUNREACH,
                   Timeout::Error,
                   OpenURI::HTTPError,
                   OpenSSL::SSL::SSLError
              licensing_warning("Can not download license file '#{license_file}' for software '#{software_name}'.")
              # If we got here, we need to fail now so we don't take a git
              # cache snapshot, or else the software build could be restored
              # from cache without fixing the license issue.
              raise_if_warnings_fatal!
            end
          end
        end
      end
    end

    STANDARD_LICENSES = {
      #
      # Below licenses are compiled based on https://opensource.org/licenses/alphabetical
      #
      "AFL-3.0" => "https://opensource.org/licenses/AFL-3.0",             # Academic Free License 3.0
      "APL-1.0" => "https://opensource.org/licenses/APL-1.0",             # Adaptive Public License
      "Apache-2.0" => "https://opensource.org/licenses/Apache-2.0",       # Apache License 2.0
      "APSL-2.0" => "https://opensource.org/licenses/APSL-2.0",           # Apple Public Source License
      "Artistic-2.0" => "https://opensource.org/licenses/Artistic-2.0",   # Artistic license 2.0
      "AAL" => "https://opensource.org/licenses/AALAAL",                  # Attribution Assurance Licenses
      "BSD-3-Clause" => "https://opensource.org/licenses/BSD-3-Clause",   # BSD 3-Clause "New" or "Revised" License
      "BSD-2-Clause" => "https://opensource.org/licenses/BSD-2-Clause",   # BSD 2-Clause "Simplified" or "FreeBSD" License
      "BSD-1-Clause" => "https://opensource.org/licenses/BSD-1-Clause",   # BSD 1-Clause
      "BSL-1.0" => "https://opensource.org/licenses/BSL-1.0",             # Boost Software License
      "CECILL-2.1" => "https://opensource.org/licenses/CECILL-2.1",       # CeCILL License 2.1
      "CATOSL-1.1" => "https://opensource.org/licenses/CATOSL-1.1",       # Computer Associates Trusted Open Source License 1.1
      "CDDL-1.0" => "https://opensource.org/licenses/CDDL-1.0",           # Common Development and Distribution License 1.0
      "CPAL-1.0" => "https://opensource.org/licenses/CPAL-1.0",           # Common Public Attribution License 1.0
      "CUA-OPL-1.0" => "https://opensource.org/licenses/CUA-OPL-1.0",     # CUA Office Public License Version 1.0
      "EUDatagrid" => "https://opensource.org/licenses/EUDatagrid",       # EU DataGrid Software License
      "EPL-1.0" => "https://opensource.org/licenses/EPL-1.0",             # Eclipse Public License 1.0
      "eCos-2.0" => "https://opensource.org/licenses/eCos-2.0",           # eCos License version 2.0
      "ECL-2.0" => "https://opensource.org/licenses/ECL-2.0",             # Educational Community License,            Version 2.0
      "EFL-2.0" => "https://opensource.org/licenses/EFL-2.0",             # Eiffel Forum License V2.0
      "Entessa" => "https://opensource.org/licenses/Entessa",             # Entessa Public License
      "EUPL-1.1" => "https://opensource.org/licenses/EUPL-1.1",           # European Union Public License,            Version 1.1
      "Fair" => "https://opensource.org/licenses/Fair",                   # Fair License
      "Frameworx-1.0" => "https://opensource.org/licenses/Frameworx-1.0", # Frameworx License
      "FPL-1.0.0" => "https://opensource.org/licenses/FPL-1.0.0",         # Free Public License 1.0.0
      "AGPL-3.0" => "https://opensource.org/licenses/AGPL-3.0",           # GNU Affero General Public License v3
      "GPL-2.0" => "https://opensource.org/licenses/GPL-2.0",             # GNU General Public License version 2.0
      "GPL-3.0" => "https://opensource.org/licenses/GPL-3.0",             # GNU General Public License version 3.0
      "LGPL-2.1" => "https://opensource.org/licenses/LGPL-2.1",           # GNU Library or "Lesser" General Public License version 2.1
      "LGPL-3.0" => "https://opensource.org/licenses/LGPL-3.0",           # GNU Library or "Lesser" General Public License version 3.0
      "HPND" => "https://opensource.org/licenses/HPND",                   # Historical Permission Notice and Disclaimer
      "IPL-1.0" => "https://opensource.org/licenses/IPL-1.0",             # IBM Public License 1.0
      "IPA" => "https://opensource.org/licenses/IPA",                     # IPA Font License
      "ISC" => "https://opensource.org/licenses/ISC",                     # ISC License
      "LPPL-1.3c" => "https://opensource.org/licenses/LPPL-1.3c",         # LaTeX Project Public License 1.3c
      "LiLiQ-P" => "https://opensource.org/licenses/LiLiQ-P",             # Licence Libre du Quebec Permissive
      "LiLiQ-R" => "https://opensource.org/licenses/LiLiQ-R",             # Licence Libre du Quebec Reciprocite
      "LiLiQ-R+" => "https://opensource.org/licenses/LiLiQ-R+",           # Licence Libre du Quebec Reciprocite forte
      "LPL-1.02" => "https://opensource.org/licenses/LPL-1.02",           # Lucent Public License Version 1.02
      "MirOS" => "https://opensource.org/licenses/MirOS",                 # MirOS Licence
      "MS-PL" => "https://opensource.org/licenses/MS-PL",                 # Microsoft Public License
      "MS-RL" => "https://opensource.org/licenses/MS-RL",                 # Microsoft Reciprocal License
      "MIT" => "https://opensource.org/licenses/MIT",                     # MIT license
      "Motosoto" => "https://opensource.org/licenses/Motosoto",           # Motosoto License
      "MPL-2.0" => "https://opensource.org/licenses/MPL-2.0",             # Mozilla Public License 2.0
      "Multics" => "https://opensource.org/licenses/Multics",             # Multics License
      "NASA-1.3" => "https://opensource.org/licenses/NASA-1.3",           # NASA Open Source Agreement 1.3
      "NTP" => "https://opensource.org/licenses/NTP",                     # NTP License
      "Naumen" => "https://opensource.org/licenses/Naumen",               # Naumen Public License
      "NGPL" => "https://opensource.org/licenses/NGPL",                   # Nethack General Public License
      "Nokia" => "https://opensource.org/licenses/Nokia",                 # Nokia Open Source License
      "NPOSL-3.0" => "https://opensource.org/licenses/NPOSL-3.0",         # Non-Profit Open Software License 3.0
      "OCLC-2.0" => "https://opensource.org/licenses/OCLC-2.0",           # OCLC Research Public License 2.0
      "OGTSL" => "https://opensource.org/licenses/OGTSL",                 # Open Group Test Suite License
      "OSL-3.0" => "https://opensource.org/licenses/OSL-3.0",             # Open Software License 3.0
      "OPL-2.1" => "https://opensource.org/licenses/OPL-2.1",             # OSET Public License version 2.1
      "PHP-3.0" => "https://opensource.org/licenses/PHP-3.0",             # PHP License 3.0
      "PostgreSQL" => "https://opensource.org/licenses/PostgreSQL",       # The PostgreSQL License
      "Python-2.0" => "https://opensource.org/licenses/Python-2.0",       # Python License
      "CNRI-Python" => "https://opensource.org/licenses/CNRI-Python",     # CNRI Python license
      "QPL-1.0" => "https://opensource.org/licenses/QPL-1.0",             # Q Public License
      "RPSL-1.0" => "https://opensource.org/licenses/RPSL-1.0",           # RealNetworks Public Source License V1.0
      "RPL-1.5" => "https://opensource.org/licenses/RPL-1.5",             # Reciprocal Public License 1.5
      "RSCPL" => "https://opensource.org/licenses/RSCPL",                 # Ricoh Source Code Public License
      "OFL-1.1" => "https://opensource.org/licenses/OFL-1.1",             # SIL Open Font License 1.1
      "SimPL-2.0" => "https://opensource.org/licenses/SimPL-2.0",         # Simple Public License 2.0
      "Sleepycat" => "https://opensource.org/licenses/Sleepycat",         # Sleepycat License
      "SPL-1.0" => "https://opensource.org/licenses/SPL-1.0",             # Sun Public License 1.0
      "Watcom-1.0" => "https://opensource.org/licenses/Watcom-1.0",       # Sybase Open Watcom Public License 1.0
      "NCSA" => "https://opensource.org/licenses/NCSA",                   # University of Illinois/NCSA Open Source License
      "UPL" => "https://opensource.org/licenses/UPL",                     # Universal Permissive License
      "VSL-1.0" => "https://opensource.org/licenses/VSL-1.0",             # Vovida Software License v. 1.0
      "W3C" => "https://opensource.org/licenses/W3C",                     # W3C License
      "WXwindows" => "https://opensource.org/licenses/WXwindows",         # wxWindows Library License
      "Xnet" => "https://opensource.org/licenses/Xnet",                   # X.Net License
      "0BSD" => "https://opensource.org/licenses/0BSD",                   # Zero Clause BSD License
      "ZPL-2.0" => "https://opensource.org/licenses/ZPL-2.0",             # Zope Public License 2.0
      "Zlib" => "https://opensource.org/licenses/Zlib",                   # zlib/libpng license
      #
      # In addition to these we would like to add some of the licenses that
      # are frequently used in our depedencies.
      #
      "Public-Domain" => "https://opensource.org/faq#public-domain",
      "Ruby" => "http://www.ruby-lang.org/en/LICENSE.txt",
      "Erlang-Public" => "http://www.erlang.org/EPLICENSE",
      "Oracle-Binary" => "http://www.oracle.com/technetwork/java/javase/terms/license/index.html",
      "OpenSSL" => "https://www.openssl.org/source/license.html",
      "Chef-MLSA" => "https://www.chef.io/online-master-agreement/"
    }.freeze
  end
end
