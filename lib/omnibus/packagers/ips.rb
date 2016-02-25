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
    # @return [Hash]

    id :ips

    setup do
      # Copy the full-stack installer into our scratch directory, accounting for
      # any excluded files.
      #
      # /opt/hamlet => /tmp/daj29013/opt/hamlet
      destination = File.join(staging_dir, project.install_dir)

      # Create the scripts staging directory
      create_directory(scripts_staging_dir)
    end

    build do

      # Generate package manifest
        generate_pkg_manifest

      # Setting up an IPS repository
        create_ips_repo

      # Publish the IPS package
        publish_ips_pkg
    end

    # @see Base#package_name
    def package_name
      "#{safe_base_package_name}@#{project.build_version},#{project.build_version}-#{project.build_iteration}:timestamp"
    end

    # The path where the package scripts in the install directory.
    #
    # @return [String]
    #
    def scripts_install_dir
      File.expand_path(File.join(project.install_dir, 'embedded/share/installp'))
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
    # Generate package manifest
    # 
    # Package manifest is generally divided into three different parts:
    # 1) Package metadata 
    # 2) Package contents 
    # 3) Package dependencies 
    #
    def generate_pkg_manifest
      # 1) Generate Package metadata 
      generate_pkg_metadata  

      # 2) Generate Package contents 
      generate_pkg_contents

      # 3) Generate Package dependencies 
      generate_pkg_deps 

      # 4) Check the final manifest
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
        destination: File.join(staging_dir, 'gen.manifestfile'),
        variables: {
          name:           safe_base_package_name,
          install_dir:    project.install_dir,
          version:        ips_version,
          description:    project.description,
          summary:	  project.friendly_name,
          arch:		  safe_architecture, 
        }
      )

      # Print the full contents of the rendered template file for mkinstallp's use
      log.debug(log_key) { "Rendered Template:\n" + File.read(File.join(staging_dir, 'gen.manifestfile')) }
      binding.pry
    end

    #
    # Create the package contents using pkgsend and pkgfmt
    #
    # @return [void]
    #
    def generate_pkg_contents
      shellout!("/usr/bin/pkgsend generate #{project.install_dir}|pkgfmt > #{File.join(staging_dir, '#{safe_base_package_name}.p5m.1')}")
      shellout!("/usr/bin/pkgmogrify -DARCH=`uname -p`  #{File.join(staging_dir, '#{safe_base_package_name}.p5m.1', 'gen_manifestfile')} |pkgfmt > #{File.join(staging_dir, '#{safe_base_package_name}.p5m.2')}")
      binding.pry
    end

    def generate_pkg_deps 
      shellout!("/usr/bin/pkgdepend -md #{project.install_dir} #{safe_base_package_name}.p5m.2 |pkgfmt > #{File.join(staging_dir, "#{safe_base_package_name}.p5m.3")}")
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

    def ips_version
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
