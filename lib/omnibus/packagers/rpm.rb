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

# need to make sure rpmbuild is installed

module Omnibus
  #
  # Builds an rpm package
  #
  class Packager::RPM < Packager::Base
    validate do
      # ...
    end

    setup do
      # Create our magic directories
      create_directory("#{staging_dir}/BUILD")
      create_directory("#{staging_dir}/RPMS")
      create_directory("#{staging_dir}/SRPMS")
      create_directory("#{staging_dir}/SOURCES")
      create_directory("#{staging_dir}/SPECS")

      # Copy the full-stack installer into the SOURCE directory, accounting for
      # any excluded files.
      FileSyncer.sync(project.install_dir, "#{staging_dir}/BUILD", exclude: exclusions)

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

    clean do
      # ...
    end

    #
    # @return [String]
    #
    def package_name
      "#{safe_package_name}-#{safe_build_version}-#{safe_build_iteration}.#{safe_architecture}.rpm"
    end

    #
    # The list of files to exclude when making the rpm. This comes from the list
    # of project exclusions and includes "common" SCM directories (like +.git+).
    #
    # @return [Array<String>]
    #
    def exclusions
      @exclusions ||= project.exclusions + %w(.git .hg .svn */.gitkeep)
    end

    #
    # Render an rpm spec file in +SPECS/#{name}.spec+ using the supplied ERB
    # template.
    #
    # @return [void]
    #
    def write_rpm_spec
      # Grab a list of all the scripts which exist and should be added
      scripts = %w(pre post preun postun verifyscript pretans posttrans)
                  .map    { |name| File.join(project.package_scripts_path, name) }
                  .select { |path| File.file?(path) }

      # Get a list of user-declared config files
      config_files = project.config_files.map { |file| rpm_safe(file) }

      # Get a list of all files
      files = FileSyncer.glob("#{staging_dir}/**/*")
                .map    { |path| path.gsub("#{staging_dir}/", '') }
                .map    { |path| rpm_safe(path) }
                .map    { |path| "/#{path}" }
                .reject { |path| config_files.include?(path) }

      render_template(template_path('rpm/spec.erb'),
        destination: spec_file,
        variables: {
          name:           safe_package_name,
          version:        safe_build_version,
          iteration:      safe_build_iteration,
          vendor:         'Omnibus <omnibus@getchef.com>', # TODO: make this configurable
          license:        'unknown', # TODO: make this configurable
          architecture:   safe_architecture,
          maintainer:     project.maintainer,
          homepage:       project.homepage,
          description:    project.description,
          priority:       'extra', # TODO: make this configurable
          category:       'default', # TODO: make this configurable
          conflicts:      project.conflicts,
          replaces:       project.replaces,
          dependencies:   project.runtime_dependencies,
          user:           project.package_user,
          group:          project.package_group,
          scripts:        scripts,
          config_files:   config_files,
          files:          files,
        }
      )
    end

    #
    # Generate the RPM file using +rpmbuild+.
    #
    # @return [void]
    #
    def create_rpm_file
      command =  "rpmbuild"
      command << " -bb"
      command << " --buildroot #{staging_dir}"
      command << " --define '_topdir #{staging_dir}'"
      command << " --define '_sourcedir #{staging_dir}'"
      command << " --define '_rpmdir #{staging_dir}/RPMS'"

      if Config.sign_pkg
        if File.exist?("#{ENV['HOME']}/.rpmmacros")
          log.info(log_key) { "Detected .rpmmacros file at `#{ENV['HOME']}'" }
        else
          log.info(log_key) { "Using default .rpmmacros file from Omnibus" }

          # Generate a temporary home directory
          home = Dir.mktmpdir

          render_template('rpm/rpmmacros.erb',
            destination: "#{home}/.rpmmacros",
            variables: {
              gpg_name: project.maintainer,
              gpg_path: "#{ENV['HOME']}/.gnupg", # TODO: Make this configurable
            }
          )

          command << " --sign"
          command << " #{spec_file}"

          shellout!("#{rpmsign} \"#{command}\"", environment: { 'HOME' => home })
        end
      else
        command << " #{spec_file}"
        shellout!("#{command}")
      end

      FileSyncer.glob("#{staging_dir}/RPMS/**/*.rpm").each do |rpm|
        copy_file(rpm, package_dir)
      end
    end

    #
    # The full path to this spec file on disk.
    #
    # @return [String]
    #
    def spec_file
      @spec_file ||= "#{staging_dir}/SPECS/#{package_name}.spec"
    end

    #
    # The path to the RPM signing script inside of Omnibus.
    #
    # @return [String]
    #
    def rpmsign
      @rpmsign ||= Omnibus.source_root.join('bin', 'sign-rpm')
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
    # RPM package names cannot contain dashes, so we will convert them to
    # underscores.
    #
    # @return [String]
    #
    def safe_package_name
      if project.package_name.include?('-')
        converted = project.package_name.gsub('-', '_')

        log.warn(log_key) do
          "RPM package names cannot contain dashes. Converting " \
          "`#{project.package_name}' to `#{converted}'."
        end

        converted
      else
        project.package_name
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
    def safe_build_version
      if project.build_version.include?('-')
        converted = project.build_version.gsub('-', '_')

        log.warn(log_key) do
          "RPM build versions cannot contain dashes. Converting " \
          "`#{project.build_version}' to `#{converted}'."
        end

        converted
      else
        project.build_version
      end
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
