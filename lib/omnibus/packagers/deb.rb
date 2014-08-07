#
# Copyright:: Copyright (c) 2014 Chef Software, Inc.
# License:: Apache License, Version 2.0
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

      # Copy over any user-specified extra package files.
      #
      # Files retain their relative paths inside the scratch directory, so
      # we need to grab the dirname of the file, create that directory, and
      # then copy the file into that directory.
      #
      # extra_package_file '/path/to/foo.txt' #=> /tmp/scratch/path/to/foo.txt
      project.extra_package_files.each do |file|
        parent      = File.dirname(file)
        destination = File.join(staging_dir, parent)

        create_directory(destination)
        copy_file(file, destination)
      end

      # Create the Debain file directory
      create_directory(debian_dir)
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
    end

    clean do
      # ...
    end

    #
    # The name of the package to create. Note, this does **not** include the
    # extension.
    #
    def package_name
      "#{safe_project_name}_#{safe_version}-#{safe_build_iteration}_#{safe_architecture}.deb"
    end

    private

    #
    # The path where Debian-specific files will live.
    #
    # @example
    #   /var/.../chef-server_11.12.4/DEBIAN
    #
    # @return [String]
    #
    def debian_dir
      @debian_dir ||= File.join(staging_dir, 'DEBIAN')
    end

    #
    # Render a control file in +#{debian_dir}/control+ using the supplied ERB
    # template.
    #
    # @return [void]
    #
    def write_control_file
      render_template(resource_path('control.erb'),
        destination: File.join(debian_dir, 'control'),
        variables: {
          name:           safe_project_name,
          version:        safe_version,
          iteration:      safe_build_iteration,
          vendor:         'Omnibus <omnibus@getchef.com>', # TODO: make this configurable
          license:        'unknown', # TODO: make this configurable
          architecture:   safe_architecture,
          maintainer:     project.maintainer,
          installed_size: package_size,
          homepage:       project.homepage,
          description:    project.description,
          priority:       'extra', # TODO: make this configurable
          section:        'misc', # TODO: make this configurable
          conflicts:      project.conflicts,
          replaces:       project.replaces,
          dependencies:   project.runtime_dependencies,
        }
      )
    end

    #
    # Render the list of config files into the conffile.
    #
    # @return [void]
    #
    def write_conffiles_file
      return if project.config_files.empty?

      render_template(resource_path('conffiles.erb'),
        destination: File.join(debian_dir, 'conffiles'),
        variables: {
          config_files: project.config_files,
        }
      )
    end

    #
    # Copy all scripts in {Project#package_scripts_path} to the control
    # directory of this repo.
    #
    # @return [void]
    #
    def write_scripts
      %w(preinst postinst prerm postrm).each do |script|
        path = File.join(project.package_scripts_path, script)

        if File.file?(path)
          log.debug(log_key) { "Adding script `#{script}' to `#{debian_dir}'" }
          copy_file(path, debian_dir)
        end
      end
    end

    #
    # Generate a list of the md5 sums of every file in the package and write it
    # to +#{debian_dir}/control/md5sums+.
    #
    # @return [void]
    #
    def write_md5_sums
      path = "#{staging_dir}/**/*"
      hash = FileSyncer.glob(path).inject({}) do |hash, path|
        if File.file?(path) && !File.symlink?(path)
          relative_path = path.gsub("#{staging_dir}/", '')
          hash[relative_path] = digest(path, :md5)
        end

        hash
      end

      render_template(resource_path('md5sums.erb'),
        destination: File.join(debian_dir, 'md5sums'),
        variables: {
          md5sums: hash,
        }
      )
    end

    #
    # Create the +.deb+ file, compressing at gzip level 9.
    #
    # @return [void]
    #
    def create_deb_file
      log.info(log_key) { "Creating .deb file" }

      # Execute the build command
      Dir.chdir(package_dir) do
        shellout!("fakeroot dpkg-deb -z9 -Zgzip -D --build #{staging_dir} #{package_name}")
      end
    end

    #
    # The size of this Debian package. This is dynamically calculated.
    #
    # @return [Fixnum]
    #
    def package_size
      @package_size ||= begin
        path  = "#{project.install_dir}/**/*"
        total = FileSyncer.glob(path).inject(0) do |size, path|
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
    end

    #
    # Return the Debian-ready project name, converting any invalid characters to
    # dashes (+-+).
    #
    # @return [String]
    #
    def safe_project_name
      if project.name =~ /\A[a-zA-Z0-9\.\+\-]+\z/
        project.name.dup
      else
        converted = project.name.gsub(/[^a-zA-Z0-9\.\+\-]+/, '-')

        log.warn(log_key) do
          "The `name' compontent of Debian package names can only include " \
          "alphabetical characters (a-z, A-Z), numbers (0-9), dots (.), " \
          "plus signs (+), and dashes (-). Converting `#{project.name}' to " \
          "`#{converted}'."
        end

        converted
      end
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
    # Return the Debian-ready version, converting any invalid characters to
    # dashes (+-+).
    #
    # @return [String]
    #
    def safe_version
      if project.build_version =~ /\A[a-zA-Z0-9\.\+\-\:]+\z/
        project.build_version.dup
      else
        converted = project.build_version.gsub(/[^a-zA-Z0-9\.\+\-\:]+/, '-')

        log.warn(log_key) do
          "The `version' compontent of Debian package names can only include " \
          "alphabetical characters (a-z, A-Z), numbers (0-9), dots (.), " \
          "plus signs (+), dashes (-), and colons (:). Converting " \
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
      case Ohai['kernel']['machine']
      when 'x86_64'
        'amd64'
      else
        Ohai['kernel']['machine']
      end
    end
  end
end
