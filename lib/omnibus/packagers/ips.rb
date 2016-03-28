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
  class Packager::IPS < Packager::Base
    id :ips

    setup do
      # Copy the full-stack installer into our scratch directory, accounting for
      # any excluded files.
      #
      # /opt/hamlet => /tmp/daj29013/proto_install/opt/hamlet
      # Create the proto_install directory inside staging_dir
      Dir.mkdir("#{staging_dir}/proto_install")
      destination = File.join(staging_path('proto_install'), project.install_dir)
      FileSyncer.sync(project.install_dir, destination, exclude: exclusions)
      create_transform_file
    end

    build do
      build_me
    end

    def build_me
      generate_pkg_manifest
      create_ips_repo
      publish_ips_pkg
      view_repo_info
      publish_as_pkg_archive
    end

    #
    # Generate package manifest
    #
    # Package manifest is generally divided into three different parts:
    # 1) Package metadata
    # 2) Package contents
    # 3) Package dependencies
    #
    def generate_pkg_manifest
      generate_pkg_metadata
      generate_pkg_contents
      generate_pkg_deps
    ##   Let's check the manifest and make sure all is right.
      check_pkg_manifest
    end

    # Generate package metadata
    #
    # Create the gen template for pkgmogrify
    #
    # @return [void]
    #
    def generate_pkg_metadata
      render_template(resource_path('gen.manifestfile.erb'),
        destination: staging_path('gen.manifestfile'),
        variables: {
          name:        safe_base_package_name,
          #install_dir: project.install_dir,
          fmri_package_name: fmri_package_name,
          description: "\"#{project.description}\"",
          summary:	   "\"#{project.friendly_name}\"",
          arch:		     safe_architecture
        }
      )

      # Print the full contents of the rendered template file for mkinstallp's use
      log.debug(log_key) { "Rendered Template:\n" + File.read(staging_path('gen.manifestfile')) }
    end

    #
    # Create the package contents using pkgsend and pkgfmt
    #
    # @return [void]
    #
    def generate_pkg_contents
      shellout!("/usr/bin/pkgsend generate #{source_dir} |pkgfmt > #{staging_path("#{safe_base_package_name}.p5m.1")}")
      shellout!("/usr/bin/pkgmogrify -DARCH=`uname -p` #{staging_path("#{safe_base_package_name}.p5m.1")} #{staging_path('gen.manifestfile')} #{staging_path('doc-transform')} |pkgfmt > #{staging_path("#{safe_base_package_name}.p5m.2")}")
    end

    def generate_pkg_deps
      shellout!("/usr/bin/pkgdepend generate -md #{source_dir} #{staging_path("#{safe_base_package_name}.p5m.2")}|pkgfmt > #{staging_path("#{safe_base_package_name}.p5m.3")}")
      shellout!("/usr/bin/pkgmogrify -DARCH=`uname -p` #{staging_path("#{safe_base_package_name}.p5m.3")} #{staging_path('doc-transform')} |pkgfmt > #{staging_path("#{safe_base_package_name}.p5m.4")}")
      shellout!("/usr/bin/pkgdepend resolve -m #{staging_path("#{safe_base_package_name}.p5m.4")}")
    end

    def check_pkg_manifest
      shellout!("/usr/bin/pkglint -c /tmp/lint-cache -r http://pkg.oracle.com/solaris/release #{staging_path("#{safe_base_package_name}.p5m.4.res")}")
    end

    def create_ips_repo
      shellout!("/usr/bin/pkgrepo create #{repo_dir}")
    end

    def publish_ips_pkg
      shellout!("/usr/bin/pkgrepo add-publisher -s #{repo_dir} #{ENV['LOGNAME']}")
      shellout!("/usr/bin/pkgsend publish -s #{repo_dir} -d #{source_dir} #{staging_path("#{safe_base_package_name}.p5m.4.res")}")
    end

    def view_repo_info
      shellout!("/usr/bin/pkgrepo info -s #{repo_dir}")
    end

    def publish_as_pkg_archive
      dest_dir = File.join(Config.package_dir, "#{safe_base_package_name}.p5p")
      shellout!("/usr/bin/pkgrecv -s #{repo_dir} -a -d #{dest_dir} #{safe_base_package_name}")
    end

    # Return the IPS-ready base package name, converting any invalid characters to
    # dashes (+-+).
    #
    # @return [String]
    #
    def safe_base_package_name
      if project.package_name =~ /\A[a-z0-9\.\+\-]+\z/
        project.package_name.dup
      else
        converted = project.package_name.downcase.gsub(/[^a-z0-9\.\+\-]+/, '-')

        log.warn(log_key) do
          "The `name' component of IPS package names can only include " \
          "lowercase alphabetical characters (a-z), numbers (0-9), dots (.), " \
          "plus signs (+), and dashes (-). Converting `#{project.package_name}' to " \
          "`#{converted}'."
        end
        converted
      end
    end

    # @see Base#package_name
    #
    def package_name
      "#{safe_base_package_name}.p5p"
    end

    # For more info about fmri see:
    # http://doc.oracle.com/cd/E23824_01/html/E21796/pkg-5.html#scrolltoc
    def fmri_package_name
      # TODO: still need to implement timestamp.
      version = project.build_version.split(/[^\d]/)[1..2].join('.')
      #version = project.build_version
      "#{safe_base_package_name}@#{version},#{version}-#{project.build_iteration}"
    end

    #docfile = staging_path('doc-transform')
    #File.open("#{staging_dir}/doc-transform", "w+") do |f|
    def create_transform_file
      pathdir = project.install_dir.split('/')[1]
      File.open("#{staging_path("doc-transform")}", "w+") do |f|
        f.write <<-EOF
        <transform dir path=#{pathdir}$ -> edit group bin sys>
        <transform file depend -> edit pkg.debug.depend.file ruby env>
        EOF
      end
    end

    def staging_path(file_name)
      File.join(staging_dir, file_name)
    end

    def source_dir
      staging_path('proto_install')
    end

    def repo_dir
      staging_path('publish/repo')
    end

    def safe_architecture
      # The #i386? and #intel? helpers come from chef-sugar
      if intel?
        'i386'
      elsif sparc?
        'sparc'
      else
        Ohai['kernel']['machine']
      end
    end
  end
end
