#
# Copyright 2016 Chef Software, Inc.
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
  class Packager::IPS < Packager::Base
    id :ips

    setup do
      create_directory(source_dir)
      # Copy the full-stack installer into our scratch directory, accounting for
      # any excluded files.
      #
      # /opt/hamlet => /tmp/daj29013/proto_install/opt/hamlet
      # Create the proto_install directory inside staging_dir
      destination = File.join(source_dir, project.install_dir)
      FileSyncer.sync(project.install_dir, destination, exclude: exclusions)
      write_transform_file
    end

    build do
      #
      # Package manifest generation is divided into the following stages:
      #
      write_pkg_metadata
      generate_pkg_contents
      generate_pkg_deps
      validate_pkg_manifest

      #
      # To create an IPS package we need to generate a repo, publish our
      # package into said repo. Finally, we export a portable `*.p5p`
      # file from this repo.
      #
      create_ips_repo
      publish_ips_pkg
      export_pkg_archive_file
    end

    #
    # @!group DSL methods
    # --------------------------------------------------

    #
    # The publisher prefix for the IPS package.
    #
    # @example
    #   identifier 'Chef'
    #
    # @param [String] val
    #   the package identifier
    #
    # @return [String]
    #
    def publisher_prefix(val = NULL)
      if null?(val)
        @publisher_prefix || "Omnibus"
      else
        @publisher_prefix = val
      end
    end
    expose :publisher_prefix

    #
    # @!endgroup
    # --------------------------------------------------

    #
    # @see Base#package_name
    #
    def package_name
      version = project.build_version.split(/[^\d]/)[0..2].join(".")
      "#{safe_base_package_name}-#{version}-#{project.build_iteration}.#{safe_architecture}.p5p"
    end

    #
    # For more info about fmri see:
    #
    #   http://docs.oracle.com/cd/E23824_01/html/E21796/pkg-5.html
    #
    def fmri_package_name
      version = project.build_version.split(/[^\d]/)[0..2].join(".")
      platform = Ohai["platform_version"]
      "#{safe_base_package_name}@#{version},#{platform}-#{project.build_iteration}"
    end

    #
    # The full path to the transform file on disk.
    #
    # @return [String]
    #
    def transform_file
      @transform_file ||= File.join(staging_dir, "doc-transform")
    end

    #
    # The full path to the pkg metadata file on disk.
    #
    # @return [String]
    #
    def pkg_metadata_file
      @pkg_metadata_file ||= File.join(staging_dir, "gen.manifestfile")
    end

    #
    # The full path to the pkg manifest file on disk.
    #
    # @return [String]
    #
    def pkg_manifest_file
      @pkg_manifest_file ||= File.join(staging_dir, "#{safe_base_package_name}.p5m")
    end

    #
    # The path to the +publish/repo+ directory inside the staging directory.
    #
    # @return [String]
    #
    def repo_dir
      @repo_dir ||= File.join(staging_dir, "publish", "repo")
    end

    #
    # The path to the +proto-install+ directory inside the staging directory.
    #
    # @return [String]
    #
    def source_dir
      @source_dir ||= File.join(staging_dir, "proto_install")
    end

    #
    # Return the IPS-ready base package name, converting any invalid characters to
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
          "The `name' component of IPS package names can only include " \
          "lowercase alphabetical characters (a-z), numbers (0-9), dots (.), " \
          "plus signs (+), and dashes (-). Converting `#{project.package_name}' to " \
          "`#{converted}'."
        end
        converted
      end
    end

    #
    # The architecture for this IPS package.
    #
    # @return [String]
    #
    def safe_architecture
      if intel?
        "i386"
      elsif sparc?
        "sparc"
      else
        Ohai["kernel"]["machine"]
      end
    end

    #
    # A set of transform rules that `pkgmogrify' will apply to the package
    # manifest.
    #
    # @return [void]
    #
    def write_transform_file
      render_template(resource_path("doc-transform.erb"),
                      destination: transform_file,
                      variables: {
                        pathdir: project.install_dir.split("/")[1],
                      })
    end

    #
    # Generate package metadata
    #
    # Create the gen template for `pkgmogrify`
    #
    # @return [void]
    #
    def write_pkg_metadata
      render_template(resource_path("gen.manifestfile.erb"),
                      destination: pkg_metadata_file,
                      variables: {
                        name: safe_base_package_name,
                        fmri_package_name: fmri_package_name,
                        description: project.description,
                        summary: project.friendly_name,
                        arch: safe_architecture,
                      })

      # Print the full contents of the rendered template file to generate package contents
      log.debug(log_key) { "Rendered Template:\n" + File.read(pkg_metadata_file) }
    end

    #
    # Create the package contents using `pkgsend` and `pkgfmt`
    #
    # @return [void]
    #
    def generate_pkg_contents
      shellout!("pkgsend generate #{source_dir} | pkgfmt > #{pkg_manifest_file}.1")
      shellout!("pkgmogrify -DARCH=`uname -p` #{pkg_manifest_file}.1 #{pkg_metadata_file} #{transform_file} | pkgfmt > #{pkg_manifest_file}.2")
    end

    #
    # Generate the package deps
    #
    # @return [void]
    #
    def generate_pkg_deps
      shellout!("pkgdepend generate -md #{source_dir} #{pkg_manifest_file}.2 | pkgfmt > #{pkg_manifest_file}.3")
      shellout!("pkgmogrify -DARCH=`uname -p` #{pkg_manifest_file}.3 #{transform_file} | pkgfmt > #{pkg_manifest_file}.4")
      shellout!("pkgdepend resolve -m #{pkg_manifest_file}.4")
    end

    #
    # Validate the generated package manifest using `pkglint`
    #
    # @return [void]
    #
    def validate_pkg_manifest
      log.info(log_key) { "Validating package manifest" }
      shellout!("pkglint -c /tmp/lint-cache -r http://pkg.oracle.com/solaris/release #{pkg_manifest_file}.4.res")
    end

    #
    # Create a local IPS repo for publishing
    #
    # @return [void]
    #
    def create_ips_repo
      shellout!("pkgrepo create #{repo_dir}")
      log.info(log_key) { "Created IPS repo: #{repo_dir}" }
    end

    #
    # Publish the IPS pkg into the local IPS repo
    #
    # @return [void]
    #
    def publish_ips_pkg
      shellout!("pkgrepo -s #{repo_dir} set publisher/prefix=#{publisher_prefix}")
      shellout!("pkgsend publish -s #{repo_dir} -d #{source_dir} #{pkg_manifest_file}.4.res")
      log.info(log_key) { "Published IPS package to repo: #{repo_dir}" }

      repo_info = shellout("pkg list -afv -g #{repo_dir}").stdout
      log.debug(log_key) do
        <<-EOH.strip
          Published IPS package:

            #{repo_info}
        EOH
      end
    end

    #
    # Convert a the published IPS pkg from the local repo into the more
    # easily distributable `*.p5p` archive.
    #
    # @return [void]
    #
    def export_pkg_archive_file
      # The destination file cannot already exist
      File.delete(package_path) if File.exist?(package_path)
      shellout!("pkgrecv -s #{repo_dir} -a -d #{package_path} #{safe_base_package_name}")
      log.info(log_key) { "Exported IPS package archive: #{package_path}" }

      list_pkgarchive = shellout("pkgrepo list -s #{package_path} '*@latest'").stdout
      log.debug(log_key) do
        <<-EOH.strip
          IPS package archive contents:

            #{list_pkgarchive}
        EOH
      end
    end
  end
end
