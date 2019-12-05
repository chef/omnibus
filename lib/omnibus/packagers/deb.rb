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
  class Packager::DEB < Packager::Base
    id :deb

    setup do
      # Copy the full-stack installer into our scratch directory, accounting for
      # any excluded files.
      #
      # /opt/hamlet => /tmp/daj29013/opt/hamlet
      skip = exclusions + debug_package_paths
      destination = File.join(staging_dir, project.install_dir)
      FileSyncer.sync(project.install_dir, destination, exclude: skip)

      if debug_build?
        destination_dbg = File.join(staging_dbg_dir, project.install_dir)
        FileSyncer.sync(project.install_dir, destination_dbg, include: debug_package_paths)
      end

      # Copy over any user-specified extra package files.
      #
      # Files retain their relative paths inside the scratch directory, so
      # we need to grab the dirname of the file, create that directory, and
      # then copy the file into that directory.
      #
      # extra_package_file '/path/to/foo.txt' #=> /tmp/scratch/path/to/foo.txt
      project.extra_package_files.each do |file|
        parent = File.dirname(file)

        if File.directory?(file)
          destination = File.join(staging_dir, file)
          create_directory(destination)
          FileSyncer.sync(file, destination)
        else
          destination = File.join(staging_dir, parent)
          create_directory(destination)
          copy_file(file, destination)
        end
      end

      # Create the Debian file directory
      create_directory(debian_dir)
      create_directory(debian_dbg_dir) if debug_build?
    end

    build do
      # Render the Debian +control+ file
      write_control_file

      # Write the conffiles
      write_conffiles_file

      # Write the scripts
      write_scripts

      # Render the md5 sums
      write_md5_sums

      # Create the deb
      create_deb_file

      # Now the debug build
      if debug_build?
        # Render the Debian +control+ file
        write_control_file(true)

        # Write the conffiles
        write_conffiles_file(true)

        # Write the scripts
        write_scripts(true)

        # Render the md5 sums
        write_md5_sums(true)

        # Create the deb
        create_deb_file(true)
      end
    end

    #
    # @!group DSL methods
    # --------------------------------------------------

    #
    # Set or return the vendor who made this package.
    #
    # @example
    #   vendor "Seth Vargo <sethvargo@gmail.com>"
    #
    # @param [String] val
    #   the vendor who make this package
    #
    # @return [String]
    #   the vendor who make this package
    #
    def vendor(val = NULL)
      if null?(val)
        @vendor || "Omnibus <omnibus@getchef.com>"
      else
        unless val.is_a?(String)
          raise InvalidValue.new(:vendor, "be a String")
        end

        @vendor = val
      end
    end
    expose :vendor

    #
    # Set or return the license for this package.
    #
    # @example
    #   license "Apache 2.0"
    #
    # @param [String] val
    #   the license for this package
    #
    # @return [String]
    #   the license for this package
    #
    def license(val = NULL)
      if null?(val)
        @license || project.license
      else
        unless val.is_a?(String)
          raise InvalidValue.new(:license, "be a String")
        end

        @license = val
      end
    end
    expose :license

    #
    # Sets or return the epoch for this package
    #
    # @example
    #   epoch 1
    # @param [Integer] val
    #   the epoch number
    #
    # @return [Integer]
    #   the epoch of the current package
    def epoch(val = NULL)
      if null?(val)
        @epoch || NULL
      else
        unless val.is_a?(Integer)
          raise InvalidValue.new(:epoch, 'be an Integer')
        end

        @epoch = val
      end
    end
    expose :epoch

    #
    # Set or return the priority for this package.
    #
    # @example
    #   priority "extra"
    #
    # @param [String] val
    #   the priority for this package
    #
    # @return [String]
    #   the priority for this package
    #
    def priority(val = NULL)
      if null?(val)
        @priority || "extra"
      else
        unless val.is_a?(String)
          raise InvalidValue.new(:priority, "be a String")
        end

        @priority = val
      end
    end
    expose :priority

    #
    # Set or return the section for this package.
    #
    # @example
    #   section "databases"
    #
    # @param [String] val
    #   the section for this package
    #
    # @return [String]
    #   the section for this package
    #
    def section(val = NULL)
      if null?(val)
        @section || "misc"
      else
        unless val.is_a?(String)
          raise InvalidValue.new(:section, "be a String")
        end

        @section = val
      end
    end
    expose :section

    #
    # @!endgroup
    # --------------------------------------------------

    #
    # The name of the package to create. Note, this does **not** include the
    # extension.
    #
    def package_name(debug = false)
      "#{safe_base_package_name(debug)}_#{safe_version}-#{safe_build_iteration}_#{safe_architecture}.deb"
    end

    #
    # The path where Debian-specific files will live.
    #
    # @example
    #   /var/.../chef-server_11.12.4/DEBIAN
    #
    # @return [String]
    #
    def debian_dir
      @debian_dir ||= File.join(staging_dir, "DEBIAN")
    end

    #
    # The path where Debian-specific debug files will live.
    #
    # @example
    #   /var/.../chef-server_11.12.4/DEBIAN
    #
    # @return [String]
    #
    def debian_dbg_dir
      @debian_dbg_dir ||= File.join(staging_dbg_dir, "DEBIAN")
    end

    #
    # Render a control file in +#{debian_dir}/control+ using the supplied ERB
    # template.
    #
    # @return [void]
    #
    def write_control_file(debug = false)
      dst_dir = debug ? debian_dbg_dir : debian_dir

      pkg_dependencies = project.runtime_dependencies
      if debug
        pkg_dependencies = ["#{safe_base_package_name} (= #{safe_epoch + safe_version}-#{safe_build_iteration})"]
      end

      render_template(resource_path("control.erb"),
                      destination: File.join(dst_dir, "control"),
                      variables: {
                        name: safe_base_package_name(debug),
                        version: safe_epoch + safe_version,
                        iteration: safe_build_iteration,
                        vendor: vendor,
                        license: license,
                        architecture: safe_architecture,
                        maintainer: project.maintainer,
                        installed_size: package_size(debug),
                        homepage: project.homepage,
                        description: project.description,
                        priority: priority,
                        section: section,
                        conflicts: project.conflicts,
                        replaces: project.replaces,
                        dependencies: pkg_dependencies,
                      })
    end

    #
    # Render the list of config files into the conffile.
    #
    # @return [void]
    #
    def write_conffiles_file(debug = false)
      return if project.config_files.empty?

      dst_dir = debian_dir
      if debug
        dst_dir = debian_dbg_dir
      end

      render_template(resource_path("conffiles.erb"),
                      destination: File.join(dst_dir, "conffiles"),
                      variables: {
                        config_files: project.config_files,
                      })
    end

    #
    # Copy all scripts in {Project#package_scripts_path} to the control
    # directory of this repo.
    #
    # @return [void]
    #
    def write_scripts(debug = false)
      dst_dir = debian_dir
      scripts_path = project.package_scripts_path
      if debug
        dst_dir = debian_dbg_dir
      end

      %w{preinst postinst prerm postrm}.each do |script|
        script_src = debug ? "#{script}-dbg" : script
        path = File.join(scripts_path, script_src)

        if File.file?(path)
          script_dst = File.join(dst_dir, script)
          log.debug(log_key) { "Adding script `#{script}' to `#{dst_dir}' from #{path}" }
          copy_file(path, script_dst)
          log.debug(log_key) { "SCRIPT FILE:  #{dst_dir}/#{script}" }
          FileUtils.chmod(0755, script_dst)
        end
      end
    end

    #
    # Generate a list of the md5 sums of every file in the package and write it
    # to +#{debian_dir}/control/md5sums+.
    #
    # @return [void]
    #
    def write_md5_sums(debug = false)
      staging_path = staging_dir
      path = "#{staging_dir}/**/*"
      dst_dir = debian_dir
      if debug
        staging_path = staging_dbg_dir
        path = "#{staging_dbg_dir}/**/*"
        dst_dir = debian_dbg_dir
      end

      hash = FileSyncer.glob(path).inject({}) do |hash, path|
        if File.file?(path) && !File.symlink?(path) && !(File.dirname(path) == dst_dir)
          relative_path = path.gsub("#{staging_path}/", "")
          hash[relative_path] = digest(path, :md5)
        end

        hash
      end

      render_template(resource_path("md5sums.erb"),
                      destination: File.join(dst_dir, "md5sums"),
                      variables: {
                        md5sums: hash,
                      })
    end

    #
    # Create the +.deb+ file, compressing at gzip level 9. The use of the
    # +fakeroot+ command is required so that the package is owned by
    # +root:root+, but the build user does not need to have sudo permissions.
    #
    # @return [void]
    #
    def create_deb_file(debug = false)
      log.info(log_key) { "Creating .deb file" }

      staging_path = staging_dir
      if debug
        staging_path = staging_dbg_dir
      end

      # Execute the build command
      Dir.chdir(Config.package_dir) do
        shellout!("fakeroot dpkg-deb -z9 -Zgzip -D --build #{staging_path} #{package_name(debug)}")
      end
    end

    #
    # The size of this Debian package. This is dynamically calculated.
    #
    # No longer memoized.
    #
    # @return [Fixnum]
    #
    def package_size(debug = false)
      path = "#{project.install_dir}/**/*"
      matches = FileSyncer.glob(path)
      extended_debug_package_paths = debug_package_paths.map do |path|
        [path, "#{path}/*"]
      end.flatten

      if debug
        skip = exclusions
      else
        skip = exclusions + extended_debug_package_paths
      end

      matches = matches.reject do |source_file|
        basename = FileSyncer.relative_path_for(source_file, project.install_dir)
        skip.any? { |exclude| File.fnmatch?(exclude, basename, File::FNM_DOTMATCH) }
      end

      if debug and not debug_package_paths.empty?
        matches = matches.reject do |source_file|
          basename = FileSyncer.relative_path_for(source_file, project.install_dir)
          extended_debug_package_paths.none? { |include| File.fnmatch?(include, basename, File::FNM_DOTMATCH) }
        end
      end

      total = matches.inject(0) do |size, path|
        unless File.directory?(path) || File.symlink?(path)
          size += File.size(path)
        end

        size
      end

      # Per http://www.debian.org/doc/debian-policy/ch-controlfields.html, the
      # disk space is given as the integer value of the estimated installed
      # size in bytes, divided by 1024 and rounded up.
      total / 1024
    end

    #
    # Return the Debian-ready base package name, converting any invalid characters to
    # dashes (+-+).
    #
    # @return [String]
    #
    def safe_base_package_name(debug = false)
      if project.package_name =~ /\A[a-z0-9\.\+\-]+\z/
        name = project.package_name.dup
      else
        converted = project.package_name.downcase.gsub(/[^a-z0-9\.\+\-]+/, "-")

        log.warn(log_key) do
          "The `name' component of Debian package names can only include " \
          "lower case alphabetical characters (a-z), numbers (0-9), dots (.), " \
          "plus signs (+), and dashes (-). Converting `#{project.package_name}' to " \
          "`#{converted}'."
        end

        name = converted
      end

      debug ? "#{name}-dbg" : name
    end

    #
    # This is actually just the regular build_iteration, but it felt lonely
    # among all the other +safe_*+ methods.
    #
    # @return [String]
    #
    def safe_build_iteration
      project.build_iteration
    end

    #
    # Returns the string to prepend to the version if needed.
    #
    # @return [String]
    #
    def safe_epoch
      null?(epoch) ? '' : "#{epoch}:"
    end

    #
    # Return the Debian-ready version, replacing all dashes (+-+) with tildes
    # (+~+) and converting any invalid characters to underscores (+_+).
    #
    # @return [String]
    #
    def safe_version
      version = project.build_version.dup

      if version =~ /\-/
        converted = version.tr("-", "~")

        log.warn(log_key) do
          "Dashes hold special significance in the Debian package versions. " \
          "Versions that contain a dash and should be considered an earlier " \
          "version (e.g. pre-releases) may actually be ordered as later " \
          "(e.g. 12.0.0-rc.6 > 12.0.0). We'll work around this by replacing " \
          "dashes (-) with tildes (~). Converting `#{project.build_version}' " \
          "to `#{converted}'."
        end

        version = converted
      end

      if version =~ /\A[a-zA-Z0-9\.\+\:\~]+\z/
        version
      else
        converted = version.gsub(/[^a-zA-Z0-9\.\+\:\~]+/, "_")

        log.warn(log_key) do
          "The `version' component of Debian package names can only include " \
          "alphabetical characters (a-z, A-Z), numbers (0-9), dots (.), " \
          "plus signs (+), dashes (-), tildes (~) and colons (:). Converting " \
          "`#{project.build_version}' to `#{converted}'."
        end

        converted
      end
    end

    #
    # Debian does not follow the standards when naming 64-bit packages.
    #
    # @return [String]
    #
    def safe_architecture
      @safe_architecture ||= shellout!("dpkg --print-architecture").stdout.split("\n").first || "noarch"
    end

    #
    # Install the specified packages
    #
    # @return [void]
    #
    def install(packages, enablerepo = NULL)
      if null?(enablerepo)
        shellout!('apt-get update')
      else
        shellout!("apt-get update -o Dir::Etc::sourcelist='sources.list.d/#{enablerepo}.list' -o Dir::Etc::sourceparts='-' -o APT::Get::List-Cleanup='0'")
      end
      shellout!("apt-get install -y --force-yes #{packages}")
    end

    #
    # Remove the specified packages
    #
    # @return [void]
    #
    def remove(packages)
      shellout!("apt-get remove -y --force-yes #{packages}")
    end
  end
end
