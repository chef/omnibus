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

require 'pry'

module Omnibus
  class Packager::IPS < Packager::Base
    id :ips

    setup do
      # Copy the full-stack installer into our scratch directory, accounting for
      # any excluded files.
      #
      # /opt/hamlet => /tmp/daj29013/opt/hamlet
      destination = staging_path(project.install_dir)
    end

    build do
      generate_pkg_manifest
      create_ips_repo
      publish_ips_pkg
    end

    def package_name

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

      # Let's check the manifest and make sure all is right.
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
          install_dir: project.install_dir,
          fmri_package_name: fmri_package_name,
          description: project.description,
          summary:	   project.friendly_name,
          arch:		     safe_architecture,
        }
      )

      # Print the full contents of the rendered template file for mkinstallp's use
      log.debug(log_key) { "Rendered Template:\n" + File.read(staging_path('gen.manifestfile')) }
      binding.pry
    end

    #
    # Create the package contents using pkgsend and pkgfmt
    #
    # @return [void]
    #
    def generate_pkg_contents
      shellout!("/usr/bin/pkgsend generate #{project.install_dir}|pkgfmt > #{staging_path("#{safe_base_package_name}.p5m.1")}")
      shellout!("/usr/bin/pkgmogrify -DARCH=`uname -p` #{staging_path("#{safe_base_package_name}.p5m.1")} #{staging_path('gen_manifestfile')} |pkgfmt > #{staging_path("#{safe_base_package_name}.p5m.2")}")
      binding.pry
    end

    def generate_pkg_deps
      shellout!("/usr/bin/pkgdepend -md #{project.install_dir} #{safe_base_package_name}.p5m.2 |pkgfmt > #{staging_path("#{safe_base_package_name}.p5m.3")}")
      shellout!("/usr/bin/pkgdepend resolve -m #{safe_base_package_name}.p5m.3")
      binding.pry
    end

    def check_pkg_manifest
      shellout!("/usr/bin/pkglint -c ./lint-cache -r http://pkg.oracle.com/solaris/release #{safe_base_package_name}.p5m.3.res")
      binding.pry
    end

    def create_ips_repo
      shellout!("/usr/bin/pkgrepo create #{ENV['HOME']}/publish/repo")
      shellout!("/usr/bin/pkgsend publish -s #{ENV['HOME']}/publish/repo -d #{project.install_dir} #{safe_base_package_name}.p5m.3.res")
      binding.pry
    end

    def publish_ips_pkg
      shellout!("/usr/bin/pkgrepo add-publisher -s #{ENV['HOME']}/publish/repo #{ENV['LOGNAME']}")
      binding.pry
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

    # For more info about fmri see:
    # http://docs.oracle.com/cd/E23824_01/html/E21796/pkg-5.html#scrolltoc
    def fmri_package_name
      # TODO: still need to implement timestamp.
      version = project.build_version.split(/[^\d]/)[0..2].join('.')
      "#{safe_base_package_name}@#{version},#{version}-#{project.build_iteration}:timestamp"
    end

    def staging_path(file_name)
      File.join(staging_dir, file_name)
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
