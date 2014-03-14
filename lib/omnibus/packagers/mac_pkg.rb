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

require 'forwardable'
require 'fileutils'
require 'omnibus/util'

module Omnibus
  module Packagers
    # Builds a Mac OS X "product" package (.pkg extension)
    #
    # Mac OS X packages are built in two stages. First, files are packaged up
    # into one or more "component" .pkg files (MacPkg only supports making a
    # single component). This is done with `pkgbuild`. Next the component(s)
    # are combined into a single "product" package, using `productbuild`. It is
    # this container package that can have custom branding (background image)
    # and a license. It can also allow for user customization of which
    # component packages to install, but MacPkg does not expose this feature.
    class MacPkg
      include Util

      extend Forwardable

      # The Omnibus::Project instance that we're packaging.
      attr_reader :project

      # !@method name
      #   @return (see Project#name)
      def_delegator :@project, :name

      # !@method version
      #   @return (see Project#build_version)
      def_delegator :@project, :build_version, :version

      # !@method iteration
      #   @return (see Project#iteration)
      def_delegator :@project, :iteration, :iteration

      # !@method identifier
      #   @return (see Project#mac_pkg_identifier)
      def_delegator :@project, :mac_pkg_identifier, :identifier

      # !@method pkg_root
      #   @return (see Project#install_path)
      def_delegator :@project, :install_path, :pkg_root

      # !@method install_location
      #   @return (see Project#install_path)
      def_delegator :@project, :install_path, :install_location

      # !@method scripts
      #   @return (see Project#package_scripts_path)
      def_delegator :@project, :package_scripts_path, :scripts

      # !@method files_path
      #   @return (see Project#files_path)
      def_delegator :@project, :files_path

      # !@method package_dir
      #   @return (see Project#package_dir)
      def_delegator :@project, :package_dir

      # @param project [Project] the omnibus project to package.
      def initialize(project)
        @project = project
      end

      # Build the package.
      def build
        # Ensure the omnibus project repo contains the stuff we need.
        validate_omnibus_project!

        # create the staging dir for intermediate build products, if needed.
        setup_staging_dir!

        # build the component package
        build_component_pkg

        # build the product package
        build_product_pkg
      end

      # Verifies that the #required_files are present in the
      # omnibus project repo.
      # @return [true] if required files are present.
      # @raise [MissingMacPkgResource] if anything is missing.
      def validate_omnibus_project!
        missing_files = required_files.select { |f| !File.exist?(f) }
        if missing_files.empty?
          true # all good
        else
          fail MissingMacPkgResource.new(missing_files)
        end
      end

      # Nukes and re-creates the staging_dir
      # @return [void]
      def setup_staging_dir!
        FileUtils.rm_rf(staging_dir)
        FileUtils.mkdir_p(staging_dir)
      end

      def build_component_pkg
        shellout!(*pkgbuild_command, shellout_opts)
      end

      def build_product_pkg
        generate_distribution
        shellout!(*productbuild_command, shellout_opts)
      end

      # The argv for a pkgbuild command that will build the component package.
      # The resulting package is only an intermediate build product. It can be
      # installed with the mac installer, but doesn't contain the data needed
      # to customize the installer UI.
      # @return [Array<String>] argv for the pkgbuild command.
      def pkgbuild_command
        %W(
          pkgbuild
          --identifier #{identifier}
          --version #{version}
          --scripts #{scripts}
          --root #{pkg_root}
          --install-location #{install_location}
          #{component_pkg_name}
        )
      end

      # The argv for a productbuild command that will build the product package.
      # The generated package is the final build product that you ship to end
      # users.
      # @return [Array<String>] argv for the productbuild command
      def productbuild_command
        %W(
          productbuild
          --distribution #{distribution_staging_path}
          --resources #{mac_pkg_files_path}
          #{product_pkg_path}
        )
      end

      # Writes the Distribution file to the staging area.
      # @return [void]
      def generate_distribution
        File.open(distribution_staging_path, File::RDWR | File::CREAT | File::EXCL, 0600) do |file|
          file.print(distribution)
        end
      end

      # The name of the (only) component package.
      # @return [String] the filename of the component .pkg file to create.
      def component_pkg_name
        "#{name}-core.pkg"
      end

      # The basename of the end-result package (that will be distributed to
      # users).
      #
      # Project uses this to generate metadata about the package after its
      # built.
      #
      # @return [String] the basename of the package file
      def package_name
        "#{name}-#{version}-#{iteration}.pkg"
      end

      def identifier
        project.mac_pkg_identifier ||
          "test.#{sanitized_maintainer}.pkg.#{sanitized_name}"
      end

      # Internally in this class we want to call this the "product package" so
      # we can be unambiguous and consistent.
      alias_method :product_pkg_name, :package_name

      # The full path where the product package was/will be written.
      #
      # @return [String] Path to the packge file.
      def product_pkg_path
        File.join(package_dir, product_pkg_name)
      end

      # @return [String] Filesystem path where the Distribution file is written.
      def distribution_staging_path
        File.join(staging_dir, 'Distribution')
      end

      # Generates the content of the Distribution file, which is used by
      # productbuild to select the component packages to include in the product
      # package. Also includes information used to customize the UI of the Mac
      # OS X installer.
      # @return [String] Distribution file content (XML)
      def distribution
        <<-END_DISTRIBTION
<?xml version="1.0" standalone="no"?>
<installer-gui-script minSpecVersion="1">
    <title>#{name.capitalize}</title>
    <background file="background.png" alignment="bottomleft" mime-type="image/png"/>
    <welcome file="welcome.html" mime-type="text/html"/>
    <license file="license.html" mime-type="text/html"/>

    <!-- Generated by productbuild - - synthesize -->
    <pkg-ref id="#{identifier}"/>
    <options customize="never" require-scripts="false"/>
    <choices-outline>
        <line choice="default">
            <line choice="#{identifier}"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="#{identifier}" visible="false">
        <pkg-ref id="#{identifier}"/>
    </choice>
    <pkg-ref id="#{identifier}" version="#{version}" onConclusion="none">#{component_pkg_name}</pkg-ref>
</installer-gui-script>
        END_DISTRIBTION
      end

      # A directory where intermediate build products are stored.
      # @return [String] Path to the directory
      def staging_dir
        File.join(project.package_tmp, 'mac-pkg')
      end

      # A list of the files that will be used to customize the "product" package.P
      # @return [Array<String>] paths to the required files.
      def required_files
        [
          background_png_path,
          license_file_path,
          welcome_file_path,
        ]
      end

      def sanitized_name
        name.gsub(/[^[:alnum:]]/, '').downcase
      end

      def sanitized_maintainer
        project.maintainer.gsub(/[^[:alnum:]]/, '').downcase
      end

      # The path to the directory inside the omnibus project's repo where the
      # pkg resource files are.
      # @return [String] path to the Resources directory
      def mac_pkg_files_path
        File.join(files_path, 'mac_pkg', 'Resources')
      end

      # @return [String] path to the license file
      def license_file_path
        File.join(mac_pkg_files_path, 'license.html')
      end

      # @return [String] path to the background image for the product package.
      def background_png_path
        File.join(mac_pkg_files_path, 'background.png')
      end

      # Path to the welcome file. This is the content that's displayed on the
      # first screen of the installer.
      # @return [String] path to the welcome file
      def welcome_file_path
        File.join(mac_pkg_files_path, 'welcome.html')
      end

      def shellout_opts
        {
          timeout: 3600,
          cwd: staging_dir,
        }
      end
    end
  end
end
