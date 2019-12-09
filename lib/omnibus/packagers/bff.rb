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
  class Packager::BFF < Packager::Base
    # @return [Hash]
    SCRIPT_MAP = {
      # Default Omnibus naming
      preinst: "Pre-installation Script",
      postinst: "Post-installation Script",
      config: "Configuration Script",
      unconfig: "Unconfiguration Script",
      prerm: "Pre_rm Script",
      postrm: "Unconfiguration Script",
    }.freeze

    id :bff

    setup do
      # Copy the full-stack installer into our scratch directory, accounting for
      # any excluded files.
      #
      # /opt/hamlet => /tmp/daj29013/opt/hamlet
      destination = File.join(staging_dir, project.install_dir)
      FileSyncer.sync(project.install_dir, destination, exclude: exclusions)

      # Create the scripts staging directory
      create_directory(scripts_staging_dir)
    end

    build do
      # Copy scripts
      write_scripts

      # Render the gen template
      write_gen_template

      # Create the package
      create_bff_file
    end

    # @see Base#package_name
    def package_name
      "#{safe_base_package_name}-#{project.build_version}-#{project.build_iteration}.#{safe_architecture}.bff"
    end

    #
    # The path where the package scripts in the install directory.
    #
    # @return [String]
    #
    def scripts_install_dir
      File.expand_path(File.join(project.install_dir, "embedded/share/installp"))
    end

    #
    # The path where the package scripts will staged.
    #
    # @return [String]
    #
    def scripts_staging_dir
      File.expand_path(File.join(staging_dir, scripts_install_dir))
    end

    #
    # Copy all scripts in {Project#package_scripts_path} to the package
    # directory.
    #
    # @return [void]
    #
    def write_scripts
      SCRIPT_MAP.each do |script, _installp_name|
        source_path = File.join(project.package_scripts_path, script.to_s)

        if File.file?(source_path)
          log.debug(log_key) { "Adding script `#{script}' to `#{scripts_staging_dir}'" }
          copy_file(source_path, scripts_staging_dir)
        end
      end
    end

    #
    # Create the gen template for +mkinstallp+.
    #
    # @return [void]
    #
    # Some details on the various lifecycle scripts:
    #
    # The order of the installp scripts is:
    # - install
    #   - pre-install
    #   - post-install
    #   - config
    # - upgrade
    #   - pre-remove (of previous version)
    #   - pre-install (previous version of software not present anymore)
    #   - post-install
    #   - config
    # - remove
    #   - unconfig
    #   - unpre-install
    #
    # To run the new version of scc, the post-install will do.
    # To run the previous version with an upgrade, use the pre-remove script.
    # To run a source install of scc upon installation of installp package, use the pre-install.
    # Upon upgrade, both the pre-remove and the pre-install scripts will run.
    # As scc has been removed between the runs of these scripts, it will only run once during upgrade.
    #
    # Keywords for scripts:
    #
    #   Pre-installation Script: /path/script
    #   Unpre-installation Script: /path/script
    #   Post-installation Script: /path/script
    #   Pre_rm Script: /path/script
    #   Configuration Script: /path/script
    #   Unconfiguration Script: /path/script
    #
    def write_gen_template
      # Get a list of all files
      files = FileSyncer.glob("#{staging_dir}/**/*").reject do |path|
        # remove any files with spaces.
        if path =~ /[[:space:]]/
          log.warn(log_key) { "Skipping packaging '#{path}' file due to whitespace in filename" }
          true
        end
      end
      files.map! do |path|
        # If paths have colons or commas, rename them and add them to a post-install,
        # post-sysck renaming script ('config') which is created if needed
        if path =~ /:|,/
          alt = path.gsub(/(:|,)/, "__")
          log.debug(log_key) { "Renaming #{path} to #{alt}" }

          File.rename(path, alt) if File.exists?(path)

          # Create a config script if needed based on resources/bff/config.erb
          config_script_path = File.join(scripts_staging_dir, "config")
          unless File.exists? config_script_path
            render_template(resource_path("config.erb"),
                            destination: "#{scripts_staging_dir}/config",
                            variables: {
                              name: project.name,
                            })
          end

          File.open(File.join(scripts_staging_dir, "config"), "a") do |file|
            file.puts "mv '#{alt.gsub(/^#{staging_dir}/, '')}' '#{path.gsub(/^#{staging_dir}/, '')}'"
          end

          path = alt
        end

        path.gsub(/^#{staging_dir}/, "")
      end

      # Create a map of scripts that exist to inject into the template
      scripts = SCRIPT_MAP.inject({}) do |hash, (script, installp_key)|
        staging_path = File.join(scripts_staging_dir, script.to_s)

        if File.file?(staging_path)
          hash[installp_key] = staging_path
          log.debug(log_key) { installp_key + ":\n" + File.read(staging_path) }
        end

        hash
      end

      render_template(resource_path("gen.template.erb"),
                      destination: File.join(staging_dir, "gen.template"),
                      variables: {
                        name: safe_base_package_name,
                        install_dir: project.install_dir,
                        friendly_name: project.friendly_name,
                        version: bff_version,
                        description: project.description,
                        files: files,
                        scripts: scripts,
                      })

      # Print the full contents of the rendered template file for mkinstallp's use
      log.debug(log_key) { "Rendered Template:\n" + File.read(File.join(staging_dir, "gen.template")) }
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
      # We are making the assumption that sudo exists.
      # Unforunately, the owner of the file in the staging directory is what
      # will be on the target machine, and mkinstallp can't tell you if that
      # is a bad thing (it usually is).
      # The match is so we only pick the lowest level of the project dir.
      # This implies that if we are in /tmp/staging/project/dir/things,
      # we will chown from 'project' on, rather than 'project/dir', which leaves
      # project owned by the build user (which is incorrect)
      # First - let's find out who we are.
      shellout!("sudo chown -Rh 0:0 #{File.join(staging_dir, project.install_dir.match(/^\/?(\w+)/).to_s)}")
      log.info(log_key) { "Creating .bff file" }

      # Since we want the owner to be root, we need to sudo the mkinstallp
      # command, otherwise it will not have access to the previously chowned
      # directory.
      shellout!("sudo /usr/sbin/mkinstallp -d #{staging_dir} -T #{File.join(staging_dir, 'gen.template')}")

      # Print the full contents of the inventory file generated by mkinstallp
      # from within the staging_dir's .info folder (where control files for the
      # packaging process are kept.)
      log.debug(log_key) do
        "With .inventory file of:\n" + File.read("#{
          File.join(staging_dir, '.info', "#{safe_base_package_name}.inventory")
        }")
      end

      # Copy the resulting package up to the package_dir
      FileSyncer.glob(File.join(staging_dir, "tmp/*.bff")).each do |bff|
        copy_file(bff, File.join(Config.package_dir, create_bff_file_name))
      end
    ensure
      # chown back to original user's uid/gid so cleanup works correctly
      original_uid = shellout!("id -u").stdout.chomp
      original_gid = shellout!("id -g").stdout.chomp

      shellout!("sudo chown -Rh #{original_uid}:#{original_gid} #{staging_dir}")
    end

    #
    # Create bff file name
    #
    # +mkinstallp+ names the bff file according to the version specified in
    # the template. We want to differentiate the build specific version
    # correctly.
    #
    # @return [String]
    #
    def create_bff_file_name
      "#{safe_base_package_name}-#{project.build_version}-#{project.build_iteration}.#{safe_architecture}.bff"
    end

    #
    # Return the BFF-ready base package name, converting any invalid characters to
    # dashes (+-+).
    #
    # @return [String]
    #
    def safe_base_package_name
      if project.package_name =~ /\A[a-z0-9\.\+\-]+\z/
        project.package_name.dup
      else
        converted = project.package_name.downcase.gsub(/[^a-z0-9\.\+\-]+/, "-")

        log.warn(log_key) do
          "The `name' component of BFF package names can only include " \
          "lowercase alphabetical characters (a-z), numbers (0-9), dots (.), " \
          "plus signs (+), and dashes (-). Converting `#{project.package_name}' to " \
          "`#{converted}'."
        end

        converted
      end
    end

    #
    # Return the BFF-specific version for this package. This is calculated
    # using the first three digits of the version, concatenated by a dot, then
    # suffixed with the build_iteration.
    #
    # @todo This is probably not the best way to extract the version and
    #   probably misses edge cases like when using git describe!
    #
    # @return [String]
    #
    def bff_version
      version = project.build_version.split(/[^\d]/)[0..2].join(".")
      "#{version}.#{project.build_iteration}"
    end

    #
    # The architecture for this RPM package.
    #
    # @return [String]
    #
    def safe_architecture
      Ohai["kernel"]["machine"]
    end
  end
end
