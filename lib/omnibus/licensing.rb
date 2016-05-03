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
      validate_license_info
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

      # Check license file exists
      if project.license != "Unspecified" && project.license_file.nil?
        licensing_warning("Project '#{project.name}' does not point to a license file.")
      end

      # Check used license is a standard license
      if project.license != "Unspecified" && !STANDARD_LICENSES.include?(project.license)
        licensing_warning("Project '#{project.name}' is using '#{project.license}' which is not one of the standard licenses identified in https://opensource.org/licenses/alphabetical. Consider using one of the standard licenses.")
      end

      # Now let's check the licensing info for software components
      license_map.each do |software_name, license_info|
        # First check if the software specified a license
        if license_info[:license] == "Unspecified"
          licensing_warning("Software '#{software_name}' does not contain licensing information.")
        end

        # Check if the software specifies any license files
        if license_info[:license] != "Unspecified" && license_info[:license_files].empty?
          licensing_warning("Software '#{software_name}' does not point to any license files.")
        end

        # Check if the software license is one of the standard licenses
        if license_info[:license] != "Unspecified" && !STANDARD_LICENSES.include?(license_info[:license])
          licensing_warning("Software '#{software_name}' uses license '#{license_info[:license]}' which is not one of the standard licenses identified in https://opensource.org/licenses/alphabetical. Consider using one of the standard licenses.")
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
                     OpenURI::HTTPError,
                     OpenSSL::SSL::SSLError
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

    STANDARD_LICENSES = [
      #
      # Below licenses are compiled based on https://opensource.org/licenses/alphabetical
      #
      "AFL-3.0",       # Academic Free License 3.0
      "AGPL-3.0",      # Affero General Public License
      "APL-1.0",       # Adaptive Public License
      "Apache-2.0",    # Apache License 2.0
      "APSL-2.0",      # Apple Public Source License
      "Artistic-2.0",  # Artistic license 2.0
      "AAL",           # Attribution Assurance Licenses
      "BSD-3-Clause",  # BSD 3-Clause "New" or "Revised" License
      "BSD-2-Clause",  # BSD 2-Clause "Simplified" or "FreeBSD" License
      "BSL-1.0",       # Boost Software License
      "CECILL-2.1",    # CeCILL License 2.1
      "CATOSL-1.1",    # Computer Associates Trusted Open Source License 1.1
      "CDDL-1.0",      # Common Development and Distribution License 1.0
      "CPAL-1.0",      # Common Public Attribution License 1.0
      "CUA-OPL-1.0",   # CUA Office Public License Version 1.0
      "EUDatagrid",    # EU DataGrid Software License
      "EPL-1.0",       # Eclipse Public License 1.0
      "eCos-2.0",      # eCos License version 2.0
      "ECL-2.0",       # Educational Community License, Version 2.0
      "EFL-2.0",       # Eiffel Forum License V2.0
      "Entessa",       # Entessa Public License
      "EUPL-1.1",      # European Union Public License, Version 1.1
      "Fair",          # Fair License
      "Frameworx-1.0", # Frameworx License
      "FPL-1.0.0",     # Free Public License 1.0.0
      "AGPL-3.0",      # GNU Affero General Public License v3
      "GPL-2.0",       # GNU General Public License version 2.0
      "GPL-3.0",       # GNU General Public License version 3.0
      "LGPL-2.1",      # GNU Library or "Lesser" General Public License version 2.1
      "LGPL-3.0",      # GNU Library or "Lesser" General Public License version 3.0
      "HPND",          # Historical Permission Notice and Disclaimer
      "IPL-1.0",       # IBM Public License 1.0
      "IPA",           # IPA Font License
      "ISC",           # ISC License
      "LPPL-1.3c",     # LaTeX Project Public License 1.3c
      "LiLiQ-P",       # Licence Libre du Quebec Permissive
      "LiLiQ-R",       # Licence Libre du Quebec Reciprocite
      "LiLiQ-R+",      # Licence Libre du Quebec Reciprocite forte
      "LPL-1.02",      # Lucent Public License Version 1.02
      "MirOS",         # MirOS Licence
      "MS-PL",         # Microsoft Public License
      "MS-RL",         # Microsoft Reciprocal License
      "MIT",           # MIT license
      "Motosoto",      # Motosoto License
      "MPL-2.0",       # Mozilla Public License 2.0
      "Multics",       # Multics License
      "NASA-1.3",      # NASA Open Source Agreement 1.3
      "NTP",           # NTP License
      "Naumen",        # Naumen Public License
      "NGPL",          # Nethack General Public License
      "Nokia",         # Nokia Open Source License
      "NPOSL-3.0",     # Non-Profit Open Software License 3.0
      "OCLC-2.0",      # OCLC Research Public License 2.0
      "OGTSL",         # Open Group Test Suite License
      "OSL-3.0",       # Open Software License 3.0
      "OPL-2.1",       # OSET Public License version 2.1
      "PHP-3.0",       # PHP License 3.0
      "PostgreSQL",    # The PostgreSQL License
      "Python-2.0",    # Python License
      "CNRI-Python",   # CNRI Python license
      "QPL-1.0",       # Q Public License
      "RPSL-1.0",      # RealNetworks Public Source License V1.0
      "RPL-1.5",       # Reciprocal Public License 1.5
      "RSCPL",         # Ricoh Source Code Public License
      "OFL-1.1",       # SIL Open Font License 1.1
      "SimPL-2.0",     # Simple Public License 2.0
      "Sleepycat",     # Sleepycat License
      "SPL-1.0",       # Sun Public License 1.0
      "Watcom-1.0",    # Sybase Open Watcom Public License 1.0
      "NCSA",          # University of Illinois/NCSA Open Source License
      "UPL",           # Universal Permissive License
      "VSL-1.0",       # Vovida Software License v. 1.0
      "W3C",           # W3C License
      "WXwindows",     # wxWindows Library License
      "Xnet",          # X.Net License
      "0BSD",          # Zero Clause BSD License
      "ZPL-2.0",       # Zope Public License 2.0
      "Zlib",          # zlib/libpng license
      #
      # In addition to these we would like to add some of the licenses that
      # are frequently used in our depedencies.
      #
      "Public-Domain", # https://opensource.org/faq#public-domain
      "Ruby",          # http://www.ruby-lang.org/en/LICENSE.txt
      "Erlang-Public", # http://www.erlang.org/EPLICENSE
      "Oracle-Binary", # http://www.oracle.com/technetwork/java/javase/terms/license/index.html
      "OpenSSL",       # https://www.openssl.org/source/license.html
      "Chef-MLSA",     # https://www.chef.io/online-master-agreement/
    ].freeze
  end
end
