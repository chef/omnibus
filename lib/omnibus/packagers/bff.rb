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
  #
  # Builds a bff package (.bff extention)
  #
  class Packager::BFF < Packager::Base
    id :bff

    validate do
      # ...
    end

    setup do
      # Copy the full-stack installer into our scratch directory, accounting for
      # any excluded files.
      #
      # /opt/hamlet => /tmp/daj29013/opt/hamlet
      destination = File.join(staging_dir, project.install_dir)
      FileSyncer.sync(project.install_dir, destination, exclude: exclusions)
    end

    build do
      # Render the gen template
      write_gen_template

      # Create the package
      create_bff_file
    end

    # @see Base#package_name
    def package_name
      "#{project.name}.#{bff_version}.#{safe_architecture}.bff"
    end

    #
    # Create the gen template for +mkinstallp+.
    #
    # @return [void]
    #
    def write_gen_template
      # Get a list of all files
      files = FileSyncer.glob("#{staging_dir}/**/*")
                .map { |path| path.gsub(/^#{staging_dir}/, '') }

      render_template(resource_path('gen.template.erb'),
        destination: File.join(staging_dir, 'gen.template'),
        variables: {
          name:           safe_project_name,
          install_dir:    project.install_dir,
          friendly_name:  project.friendly_name,
          version:        bff_version,
          description:    project.description,
          files:          files,

          # Add configuration files
          configuration_script: resource_path('postinstall.sh'),
          unconfiguration_script: resource_path('unpostinstall.sh'),
        }
      )
    end

    #
    # Create the bff file using +mkinstallp+.
    #
    # Warning: This command runs as sudo! AIX requires the use of sudo to run
    # the +mkinstallp+ command.
    #
    # @return [void]
    #
    def create_bff_file
      log.info(log_key) { "Creating .bff file" }

      shellout!("/usr/sbin/mkinstallp -d #{staging_dir} -T #{staging_dir}/gen.template")

      # Copy the resulting package up to the package_dir
      FileSyncer.glob("#{staging_dir}/*.bff").each do |bff|
        copy_file(bff, package_dir)
      end
    end

    #
    # Return the BFF-ready project name, converting any invalid characters to
    # dashes (+-+).
    #
    # @return [String]
    #
    def safe_project_name
      if project.name =~ /\A[a-z0-9\.\+\-]+\z/
        project.name.dup
      else
        converted = project.name.downcase.gsub(/[^a-z0-9\.\+\-]+/, '-')

        log.warn(log_key) do
          "The `name' compontent of BFF package names can only include " \
          "lowercase alphabetical characters (a-z), numbers (0-9), dots (.), " \
          "plus signs (+), and dashes (-). Converting `#{project.name}' to " \
          "`#{converted}'."
        end

        converted
      end
    end

    #
    # Return the BFF-specific version for this package. This is calculated
    # using the first two digits of the version, concatenated by a dot, then
    # suffixed with the build_iteration.
    #
    # @todo This is probably not the best way to extract the version and
    #   probably misses edge cases like when using git describe!
    #
    # @return [String]
    #
    def bff_version
      version = project.build_version.split(/[^\d]/)[0..2].join('.')
      "#{version}.#{project.build_iteration}"
    end

    #
    # The architecture for this RPM package.
    #
    # @return [String]
    #
    def safe_architecture
      Ohai['kernel']['machine']
    end
  end
end
