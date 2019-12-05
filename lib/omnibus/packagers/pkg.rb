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
  class Packager::PKG < Packager::Base
    # @return [Hash]
    SCRIPT_MAP = {
      # Default Omnibus naming
      preinst: "preinstall",
      postinst: "postinstall",
      # Default PKG naming
      preinstall: "preinstall",
      postinstall: "postinstall",
    }.freeze

    id :pkg

    setup do
      # Create the resources directory
      create_directory(resources_dir)

      # Create the scripts directory
      create_directory(scripts_dir)

      # Render the license
      render_template(resource_path("license.html.erb"),
                      destination: "#{resources_dir}/license.html",
                      variables: {
                        name: project.name,
                        friendly_name: project.friendly_name,
                        maintainer: project.maintainer,
                        build_version: project.build_version,
                        package_name: project.package_name,
                      })

      # Render the welcome template
      render_template(resource_path("welcome.html.erb"),
                      destination: "#{resources_dir}/welcome.html",
                      variables: {
                        name: project.name,
                        friendly_name: project.friendly_name,
                        maintainer: project.maintainer,
                        build_version: project.build_version,
                        package_name: project.package_name,
                      })

      # "Render" the assets
      copy_file(resource_path("background.png"), "#{resources_dir}/background.png")
    end

    build do
      write_scripts

      build_component_pkg

      write_distribution_file

      build_product_pkg
    end

    #
    # @!group DSL methods
    # --------------------------------------------------

    #
    # The identifer for the PKG package.
    #
    # @example
    #   identifier 'com.getchef.chefdk'
    #
    # @param [String] val
    #   the package identifier
    #
    # @return [String]
    #
    def identifier(val = NULL)
      if null?(val)
        @identifier
      else
        @identifier = val
      end
    end
    expose :identifier

    #
    # Set or return the signing identity. If this value is provided, Omnibus
    # will attempt to sign the PKG.
    #
    # @example
    #   signing_identity "foo"
    #
    # @param [String] val
    #   the identity to use when signing the PKG
    #
    # @return [String]
    #   the PKG-signing identity
    #
    def signing_identity(val = NULL)
      if null?(val)
        @signing_identity
      else
        @signing_identity = val
      end
    end
    expose :signing_identity

    #
    # @!endgroup
    # --------------------------------------------------

    # @see Base#package_name
    def package_name
      "#{safe_base_package_name}-#{safe_version}-#{safe_build_iteration}.pkg"
    end

    #
    # The full path where the product package was/will be written.
    #
    # @return [String]
    #
    def final_pkg
      File.expand_path("#{Config.package_dir}/#{package_name}")
    end

    #
    # The path where the product package resources will live. We cannot store
    # resources in the top-level staging dir, because +productbuild+'s
    # +--resources+ flag expects a directory that does not contain the parent
    # package.
    #
    # @return [String]
    #
    def resources_dir
      File.expand_path("#{staging_dir}/Resources")
    end

    #
    # The path where the package scripts will live. We cannot store
    # scripts in the top-level staging dir, because +pkgbuild+'s
    # +--scripts+ flag expects a directory that does not contain the parent
    # package.
    #
    # @return [String]
    #
    def scripts_dir
      File.expand_path("#{staging_dir}/Scripts")
    end

    #
    # Copy all scripts in {Project#package_scripts_path} to the package
    # directory.
    #
    # @return [void]
    #
    def write_scripts
      SCRIPT_MAP.each do |source, destination|
        source_path = File.join(project.package_scripts_path, source.to_s)

        if File.file?(source_path)
          destination_path = File.join(scripts_dir, destination)
          log.debug(log_key) { "Adding script `#{source}' to `#{destination_path}'" }
          copy_file(source_path, destination_path)
        end
      end
    end

    #
    # Construct the intermediate build product. It can be installed with the
    # Installer.app, but doesn't contain the data needed to customize the
    # installer UI.
    #
    # @return [void]
    #
    def build_component_pkg
      command = <<-EOH.gsub(/^ {8}/, "")
        pkgbuild \\
          --identifier "#{safe_identifier}" \\
          --version "#{safe_version}" \\
          --scripts "#{scripts_dir}" \\
          --root "#{project.install_dir}" \\
          --install-location "#{project.install_dir}" \\
          "#{component_pkg}"
      EOH

      Dir.chdir(staging_dir) do
        shellout!(command)
      end
    end

    #
    # Write the Distribution file to the staging area. This method generates the
    # content of the Distribution file, which is used by +productbuild+ to
    # select the component packages to include in the product package.
    #
    # It also includes information used to customize the UI of the Mac OS X
    # installer.
    #
    # @return [void]
    #
    def write_distribution_file
      render_template(resource_path("distribution.xml.erb"),
                      destination: "#{staging_dir}/Distribution",
                      mode: 0600,
                      variables: {
                        friendly_name: project.friendly_name,
                        identifier: safe_identifier,
                        version: safe_version,
                        component_pkg: component_pkg,
                      })
    end

    #
    # Construct the product package. The generated package is the final build
    # product that is shipped to end users.
    #
    # @return [void]
    #
    def build_product_pkg
      command = <<-EOH.gsub(/^ {8}/, "")
        productbuild \\
          --distribution "#{staging_dir}/Distribution" \\
          --resources "#{resources_dir}" \\
      EOH

      command << %Q{  --sign "#{signing_identity}" \\\n} if signing_identity
      command << %Q{  "#{final_pkg}"}
      command << %Q{\n}

      Dir.chdir(staging_dir) do
        shellout!(command)
      end
    end

    #
    # The name of the (only) component package.
    #
    # @return [String] the filename of the component .pkg file to create.
    #
    def component_pkg
      "#{safe_base_package_name}-core.pkg"
    end

    #
    # Return the PKG-ready base package name, removing any invalid characters.
    #
    # @return [String]
    #
    def safe_base_package_name
      if project.package_name =~ /\A[[:alnum:]-]+\z/
        project.package_name.dup
      else
        converted = project.package_name.downcase.gsub(/[^[:alnum:]+]/, "")

        log.warn(log_key) do
          "The `name' component of Mac package names can only include " \
          "alphabetical characters (a-z, A-Z), numbers (0-9), and -. Converting " \
          "`#{project.package_name}' to `#{converted}'."
        end

        converted
      end
    end

    #
    # The identifier for this mac package (the com.whatever.thing.whatever).
    # This is a configurable project value, but a default value is calculated if
    # one is not given.
    #
    # @return [String]
    #
    def safe_identifier
      return identifier if identifier

      maintainer = project.maintainer.gsub(/[^[:alnum:]+]/, "").downcase
      "test.#{maintainer}.pkg.#{safe_base_package_name}"
    end

    #
    # This is actually just the regular build_iternation, but it felt lonely
    # among all the other +safe_*+ methods.
    #
    # @return [String]
    #
    def safe_build_iteration
      project.build_iteration
    end

    #
    # Return the PKG-ready version, converting any invalid characters to
    # dashes (+-+).
    #
    # @return [String]
    #
    def safe_version
      if project.build_version =~ /\A[a-zA-Z0-9\.\+\-]+\z/
        project.build_version.dup
      else
        converted = project.build_version.gsub(/[^a-zA-Z0-9\.\+\-]+/, "-")

        log.warn(log_key) do
          "The `version' component of Mac package names can only include " \
          "alphabetical characters (a-z, A-Z), numbers (0-9), dots (.), " \
          "plus signs (+), and dashes (-). Converting " \
          "`#{project.build_version}' to `#{converted}'."
        end

        converted
      end
    end
  end
end
