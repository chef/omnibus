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

# need to make sure rpmbuild is installed

module Omnibus
  class Packager::RPM < Packager::Base
    # @return [Hash]
    SCRIPT_MAP = {
      # Default Omnibus naming
      preinst:  "pre",
      postinst: "post",
      prerm:    "preun",
      postrm:   "postun",
      # Default RPM naming
      pre:          "pre",
      post:         "post",
      preun:        "preun",
      postun:       "postun",
      verifyscript: "verifyscript",
      pretans:      "pretans",
      posttrans:    "posttrans",
    }.freeze

    id :rpm

    setup do
      # Create our magic directories
      create_directory("#{staging_dir}/BUILD")
      create_directory("#{staging_dir}/RPMS")
      create_directory("#{staging_dir}/SRPMS")
      create_directory("#{staging_dir}/SOURCES")
      create_directory("#{staging_dir}/SPECS")

      # Copy the full-stack installer into the SOURCE directory, accounting for
      # any excluded files.
      #
      # /opt/hamlet => /tmp/daj29013/BUILD/opt/hamlet
      destination = File.join(build_dir, project.install_dir)
      FileSyncer.sync(project.install_dir, destination, exclude: exclusions)

      # Copy over any user-specified extra package files.
      #
      # Files retain their relative paths inside the scratch directory, so
      # we need to grab the dirname of the file, create that directory, and
      # then copy the file into that directory.
      #
      # extra_package_file '/path/to/foo.txt' #=> /tmp/BUILD/path/to/foo.txt
      project.extra_package_files.each do |file|
        parent      = File.dirname(file)
        destination = File.join("#{staging_dir}/BUILD", parent)

        create_directory(destination)
        copy_file(file, destination)
      end
    end

    build do
      # Generate the spec
      write_rpm_spec

      # Generate the rpm
      create_rpm_file
    end

    #
    # @!group DSL methods
    # --------------------------------------------------

    #
    # Set or return the signing passphrase. If this value is provided,
    # Omnibus will attempt to sign the RPM.
    #
    # @example
    #   signing_passphrase "foo"
    #
    # @param [String] val
    #   the passphrase to use when signing the RPM
    #
    # @return [String]
    #   the RPM-signing passphrase
    #
    def signing_passphrase(val = NULL)
      if null?(val)
        @signing_passphrase
      else
        @signing_passphrase = val
      end
    end
    expose :signing_passphrase

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
    # Set or return the category for this package.
    #
    # @example
    #   category "databases"
    #
    # @param [String] val
    #   the category for this package
    #
    # @return [String]
    #   the category for this package
    #
    def category(val = NULL)
      if null?(val)
        @category || "default"
      else
        unless val.is_a?(String)
          raise InvalidValue.new(:category, "be a String")
        end

        @category = val
      end
    end
    expose :category

    #
    # Set or return the dist_tag for this package
    #
    # The Dist Tag for this RPM package as per the Fedora packaging guidlines.
    #
    # @see http://fedoraproject.org/wiki/Packaging:DistTag
    #
    # @example
    #   dist_tag ".#{Omnibus::Metadata.platform_shortname}#{Omnibus::Metadata.platform_version}"
    #
    # @param [String] val
    #   the dist_tag for this package
    #
    # @return [String]
    #   the dist_tag for this package
    #
    def dist_tag(val = NULL)
      if null?(val)
        @dist_tag || ".#{Omnibus::Metadata.platform_shortname}#{Omnibus::Metadata.platform_version}"
      else
        @dist_tag = val
      end
    end
    expose :dist_tag

    #
    # @!endgroup
    # --------------------------------------------------

    #
    # @return [String]
    #
    def package_name
      if dist_tag
        "#{safe_base_package_name}-#{safe_version}-#{safe_build_iteration}#{dist_tag}.#{safe_architecture}.rpm"
      else
        "#{safe_base_package_name}-#{safe_version}-#{safe_build_iteration}.#{safe_architecture}.rpm"
      end
    end

    #
    # The path to the +BUILD+ directory inside the staging directory.
    #
    # @return [String]
    #
    def build_dir
      @build_dir ||= File.join(staging_dir, "BUILD")
    end

    #
    # Get a list of user-declared config files
    #
    # @return [Array]
    #
    def config_files
      @config_files ||= project.config_files.map { |file| rpm_safe(file) }
    end

    #
    # Directories owned by the filesystem package:
    # http://fedoraproject.org/wiki/Packaging:Guidelines#File_and_Directory_Ownership
    #
    # @return [Array]
    #
    def filesystem_directories
      @filesystem_directories ||= IO.readlines(resource_path("filesystem_list")).map { |f| f.chomp }
    end

    #
    # Mark filesystem directories with ownership and permissions specified in the filesystem package
    # https://git.fedorahosted.org/cgit/filesystem.git/plain/filesystem.spec
    #
    # @return [String]
    #
    def mark_filesystem_directories(fsdir)
      if fsdir.eql?("/") || fsdir.eql?("/usr/lib") || fsdir.eql?("/usr/share/empty")
        return "%dir %attr(0555,root,root) #{fsdir}"
      elsif filesystem_directories.include?(fsdir)
        return "%dir %attr(0755,root,root) #{fsdir}"
      else
        return "%dir #{fsdir}"
      end
    end

    #
    # Render an rpm spec file in +SPECS/#{name}.spec+ using the supplied ERB
    # template.
    #
    # @return [void]
    #
    def write_rpm_spec
      # Create a map of scripts that exist and their contents
      scripts = SCRIPT_MAP.inject({}) do |hash, (source, destination)|
        path =  File.join(project.package_scripts_path, source.to_s)

        if File.file?(path)
          hash[destination] = File.read(path)
        end

        hash
      end

      # Get a list of all files
      files = FileSyncer.glob("#{build_dir}/**/*")
                .map { |path| build_filepath(path) }

      render_template(resource_path("spec.erb"),
        destination: spec_file,
        variables: {
          name:            safe_base_package_name,
          version:         safe_version,
          iteration:       safe_build_iteration,
          vendor:          vendor,
          license:         license,
          dist_tag:        dist_tag,
          maintainer:      project.maintainer,
          homepage:        project.homepage,
          description:     project.description,
          priority:        priority,
          category:        category,
          conflicts:       project.conflicts,
          replaces:        project.replaces,
          provides:        project.provides,
          dependencies:    project.runtime_dependencies,
          user:            project.package_user,
          group:           project.package_group,
          scripts:         scripts,
          config_files:    config_files,
          files:           files,
          build_dir:       build_dir,
          platform_family: Ohai["platform_family"],
        }
      )
    end

    #
    # Generate the RPM file using +rpmbuild+. Unlike debian,the +fakeroot+
    # command is not required for the package to be owned by +root:root+. The
    # rpmuser specified in the spec file dictates this.
    #
    # @return [void]
    #
    def create_rpm_file
      command =  %{rpmbuild}
      command << %{ --target #{safe_architecture}}
      command << %{ -bb}
      command << %{ --buildroot #{staging_dir}/BUILD}
      command << %{ --define '_topdir #{staging_dir}'}

      if signing_passphrase
        log.info(log_key) { "Signing enabled for .rpm file" }

        if File.exist?("#{ENV['HOME']}/.rpmmacros")
          log.info(log_key) { "Detected .rpmmacros file at `#{ENV['HOME']}'" }
          home = ENV["HOME"]
        else
          log.info(log_key) { "Using default .rpmmacros file from Omnibus" }

          # Generate a temporary home directory
          home = Dir.mktmpdir

          render_template(resource_path("rpmmacros.erb"),
            destination: "#{home}/.rpmmacros",
            variables: {
              gpg_name: project.maintainer,
              gpg_path: "#{ENV['HOME']}/.gnupg", # TODO: Make this configurable
            }
          )
        end

        command << " --sign"
        command << " #{spec_file}"

        with_rpm_signing do |signing_script|
          log.info(log_key) { "Creating .rpm file" }
          shellout!("#{signing_script} \"#{command}\"", environment: { "HOME" => home })
        end
      else
        log.info(log_key) { "Creating .rpm file" }
        command << " #{spec_file}"
        shellout!("#{command}")
      end

      FileSyncer.glob("#{staging_dir}/RPMS/**/*.rpm").each do |rpm|
        copy_file(rpm, Config.package_dir)
      end
    end

    #
    # Convert the path of a file in the staging directory to an entry for use in the spec file.
    #
    # @return [String]
    #
    def build_filepath(path)
      filepath = rpm_safe("/" + path.gsub("#{build_dir}/", ""))
      return if config_files.include?(filepath)
      full_path = build_dir + filepath.gsub("[%]", "%")
      # FileSyncer.glob quotes pathnames that contain spaces, which is a problem on el7
      full_path.delete!('"')
      # Mark directories with the %dir directive to prevent rpmbuild from counting their contents twice.
      return mark_filesystem_directories(filepath) if !File.symlink?(full_path) && File.directory?(full_path)
      filepath
    end

    #
    # The full path to this spec file on disk.
    #
    # @return [String]
    #
    def spec_file
      "#{staging_dir}/SPECS/#{package_name}.spec"
    end

    #
    # Render the rpm signing script with secure permissions, call the given
    # block with the path to the script, and ensure deletion of the script from
    # disk since it contains sensitive information.
    #
    # @param [Proc] block
    #   the block to call
    #
    # @return [String]
    #
    def with_rpm_signing(&block)
      directory   = Dir.mktmpdir
      destination = "#{directory}/sign-rpm"

      render_template(resource_path("signing.erb"),
        destination: destination,
        mode: 0700,
        variables: {
          passphrase: signing_passphrase,
        }
      )

      # Yield the destination to the block
      yield(destination)
    ensure
      remove_file(destination)
      remove_directory(directory)
    end

    #
    # Generate an RPM-safe name from the given string, doing the following:
    #
    # - Replace [ with [\[] to make rpm not use globs
    # - Replace * with [*] to make rpm not use globs
    # - Replace ? with [?] to make rpm not use globs
    # - Replace % with [%] to make rpm not expand macros
    #
    # @param [String] string
    #   the string to sanitize
    #
    def rpm_safe(string)
      string = "\"#{string}\"" if string[/\s/]

      string.dup
        .gsub("[", "[\\[]")
        .gsub("*", "[*]")
        .gsub("?", "[?]")
        .gsub("%", "[%]")
    end

    #
    # Return the RPM-ready base package name, converting any invalid characters to
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
          "The `name' component of RPM package names can only include " \
          "lowercase alphabetical characters (a-z), numbers (0-9), dots (.), " \
          "plus signs (+), and dashes (-). Converting `#{project.package_name}' to " \
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
    # RPM package versions cannot contain dashes, so we will convert them to
    # underscores.
    #
    # @return [String]
    #
    def safe_version
      version = project.build_version.dup

      # RPM 4.10+ added support for using the tilde (~) as a way to mark
      # versions as lower priority in comparisons. More details on this
      # feature can be found here:
      #
      #   http://rpm.org/ticket/56
      #
      if version =~ /\-/
        if Ohai["platform_family"] == "wrlinux"
          converted = version.tr("-", "_") #WRL has an elderly RPM version
          log.warn(log_key) do
            "Omnibus replaces dashes (-) with tildes (~) so pre-release " \
            "versions get sorted earlier than final versions.  However, the " \
            "version of rpmbuild on Wind River Linux does not support this. " \
            "All dashes will be replaced with underscores (_). Converting " \
            "`#{project.build_version}' to `#{converted}'."
          end
        else
          converted = version.tr("-", "~")
          log.warn(log_key) do
            "Tildes hold special significance in the RPM package versions. " \
            "They mark a version as lower priority in RPM's version compare " \
            "logic. We'll replace all dashes (-) with tildes (~) so pre-release" \
            "versions get sorted earlier then final versions. Converting" \
            "`#{project.build_version}' to `#{converted}'."
          end
        end

        version = converted
      end

      if version =~ /\A[a-zA-Z0-9\.\+\~]+\z/
        version
      else
        converted = version.gsub(/[^a-zA-Z0-9\.\+\~]+/, "_")

        log.warn(log_key) do
          "The `version' component of RPM package names can only include " \
          "alphabetical characters (a-z, A-Z), numbers (0-9), dots (.), " \
          "plus signs (+), tildes (~) and underscores (_). Converting " \
          "`#{project.build_version}' to `#{converted}'."
        end

        converted
      end
    end

    #
    # The architecture for this RPM package.
    #
    # @return [String]
    #
    def safe_architecture
      case Ohai["kernel"]["machine"]
      when "i686"
        "i386"
      when "armv6l"
        if Ohai["platform"] == "pidora"
          "armv6hl"
        else
          "armv6l"
        end
      else
        Ohai["kernel"]["machine"]
      end
    end
  end
end
