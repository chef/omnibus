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

module Omnibus
  class Packager::Makeself < Packager::Base
    # @return [Hash]
    SCRIPT_MAP = {
      # Default Omnibus naming
      postinst: "postinst",
    }.freeze

    id :makeself

    setup do
      # Copy the full-stack installer into our scratch directory, accounting for
      # any excluded files.
      #
      # /opt/hamlet => /tmp/daj29013
      FileSyncer.sync(project.install_dir, staging_dir, exclude: exclusions)
    end

    build do
      # Write the scripts
      write_scripts

      # Write the makeselfinst file
      write_makeselfinst

      # Create the makeself archive
      create_makeself_package
    end

    # @see Base#package_name
    def package_name
      "#{project.package_name}-#{project.build_version}_#{project.build_iteration}.#{safe_architecture}.sh"
    end

    #
    # The path to the makeself script - the default should almost always be
    # fine!
    #
    # @return [String]
    #
    def makeself
      resource_path("makeself.sh")
    end

    #
    # The path to the makeself-header script - the default should almost always
    # be fine!
    #
    # @return [String]
    #
    def makeself_header
      resource_path("makeself-header.sh")
    end

    #
    # Render a makeselfinst in the staging directory using the supplied ERB
    # template. This file will be used to move the contents of the self-
    # extracting archive into place following extraction.
    #
    # @return [void]
    #
    def write_makeselfinst
      makeselfinst_staging_path = File.join(staging_dir, "makeselfinst")
      render_template(resource_path("makeselfinst.erb"),
                      destination: makeselfinst_staging_path,
                      variables: {
                        install_dir: project.install_dir,
                      })
      FileUtils.chmod(0755, makeselfinst_staging_path)
    end

    #
    # Copy all scripts in {Project#package_scripts_path} to the staging
    # directory.
    #
    # @return [void]
    #
    def write_scripts
      SCRIPT_MAP.each do |source, destination|
        source_path = File.join(project.package_scripts_path, source.to_s)

        if File.file?(source_path)
          destination_path = File.join(staging_dir, destination)
          log.debug(log_key) { "Adding script `#{source}' to `#{destination_path}'" }
          copy_file(source_path, destination_path)
        end
      end
    end

    #
    # Run the actual makeself command, publishing the generated package.
    #
    # @return [void]
    #
    def create_makeself_package
      log.info(log_key) { "Creating makeself package" }

      Dir.chdir(staging_dir) do
        shellout! <<-EOH.gsub(/^ {10}/, "")
          #{makeself} \\
            --header "#{makeself_header}" \\
            --gzip \\
            "#{staging_dir}" \\
            "#{package_name}" \\
            "#{project.description}" \\
            "./makeselfinst"
        EOH
      end

      FileSyncer.glob("#{staging_dir}/*.sh").each do |makeself|
        copy_file(makeself, Config.package_dir)
      end
    end

    #
    # The architecture for this makeself package.
    #
    # @return [String]
    #
    def safe_architecture
      Ohai["kernel"]["machine"]
    end
  end
end
