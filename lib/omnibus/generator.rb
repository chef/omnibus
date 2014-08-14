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

require 'thor'

module Omnibus
  class Generator < Thor::Group
    include Thor::Actions

    namespace :new

    argument :name,
      banner: 'NAME',
      desc: 'The name of the Omnibus project',
      type: :string,
      required: true

    class_option :path,
      banner: 'PATH',
      aliases: '-p',
      desc: 'The path to create the Omnibus project',
      type: :string,
      default: '.'

    class_option :bff_assets,
      desc: 'Generate AIX bff assets',
      type: :boolean,
      default: false

    class_option :deb_assets,
      desc: 'Generate Debian deb assets',
      type: :boolean,
      default: false

    class_option :dmg_assets,
      desc: 'Generate Mac OS X dmg assets',
      type: :boolean,
      default: false

    class_option :makeself_assets,
      desc: 'Generate makeself assets',
      type: :boolean,
      default: false

    class_option :msi_assets,
      desc: 'Generate Windows MSI assets',
      type: :boolean,
      default: false

    class_option :pkg_assets,
      desc: 'Generate Mac OS X pkg assets',
      type: :boolean,
      default: false

    class_option :rpm_assets,
      desc: 'Generate RHEL/CentOS rpm assets',
      type: :boolean,
      default: false

    class << self
      # Set the source root for Thor
      def source_root
        File.expand_path('../generator_files', __FILE__)
      end
    end

    def create_project_files
      template('Gemfile.erb', "#{target}/Gemfile", template_options)
      template('gitignore.erb', "#{target}/.gitignore", template_options)
      template('README.md.erb', "#{target}/README.md", template_options)
      template('omnibus.rb.erb', "#{target}/omnibus.rb", template_options)
    end

    def create_project_definition
      template('config/projects/project.rb.erb', "#{target}/config/projects/#{name}.rb", template_options)
    end

    def create_example_software_definitions
      template('config/software/zlib.rb.erb', "#{target}/config/software/#{name}-zlib.rb", template_options)
    end

    def create_kitchen_files
      template('.kitchen.local.yml.erb', "#{target}/.kitchen.local.yml", template_options)
      template('.kitchen.yml.erb', "#{target}/.kitchen.yml", template_options)
      template('Berksfile.erb', "#{target}/Berksfile", template_options)
    end

    def create_package_scripts
      %w(preinst prerm postinst postrm).each do |package_script|
        script_path = "#{target}/package-scripts/#{name}/#{package_script}"
        template("package_scripts/#{package_script}.erb", script_path, template_options)

        # Ensure the package script is executable
        chmod(script_path, 0755)
      end
    end

    def create_bff_assets
      return unless options[:bff_assets]

      copy_file(resource_path('bff/gen.template.erb'), "#{target}/resources/bff/gen.template.erb")
      copy_file(resource_path('bff/postinstall.sh'), "#{target}/resources/bff/postinstall.sh")
      copy_file(resource_path('bff/unpostinstall.sh'), "#{target}/resources/bff/unpostinstall.sh")
    end

    def create_deb_assets
      return unless options[:deb_assets]

      copy_file(resource_path('deb/conffiles.erb'), "#{target}/resources/deb/conffiles.erb")
      copy_file(resource_path('deb/control.erb'), "#{target}/resources/deb/control.erb")
      copy_file(resource_path('deb/md5sums.erb'), "#{target}/resources/deb/md5sums.erb")
    end

    def create_dmg_assets
      return unless options[:dmg_assets]

      copy_file(resource_path('dmg/background.png'), "#{target}/resources/dmg/background.png")
      copy_file(resource_path('dmg/icon.png'), "#{target}/resources/dmg/icon.png")
    end

    def create_makeself_assets
      return unless options[:makeself_assets]

      copy_file(resource_path('makeself/post_extract.sh.erb'), "#{target}/resources/makeself/post_extract.sh.erb")
    end

    def create_msi_assets
      return unless options[:msi_assets]

      copy_file(resource_path('msi/localization-en-us.wxl.erb'), "#{target}/resources/msi/localization-en-us.wxl.erb")
      copy_file(resource_path('msi/parameters.wxi.erb'), "#{target}/resources/msi/parameters.wxi.erb")
      copy_file(resource_path('msi/source.wxs.erb'), "#{target}/resources/msi/source.wxs.erb")

      copy_file(resource_path('msi/assets/LICENSE.rtf'), "#{target}/resources/msi/assets/LICENSE.rtf")
      copy_file(resource_path('msi/assets/banner_background.bmp'), "#{target}/resources/msi/assets/banner_background.bmp")
      copy_file(resource_path('msi/assets/dialog_background.bmp'), "#{target}/resources/msi/assets/dialog_background.bmp")
      copy_file(resource_path('msi/assets/project.ico'), "#{target}/resources/msi/assets/project.ico")
      copy_file(resource_path('msi/assets/project_16x16.ico'), "#{target}/resources/msi/assets/project_16x16.ico")
      copy_file(resource_path('msi/assets/project_32x32.ico'), "#{target}/resources/msi/assets/project_32x32.ico")
    end

    def create_pkg_assets
      return unless options[:pkg_assets]

      copy_file(resource_path('pkg/background.png'), "#{target}/resources/pkg/background.png")
      copy_file(resource_path('pkg/license.html.erb'), "#{target}/resources/pkg/license.html.erb")
      copy_file(resource_path('pkg/welcome.html.erb'), "#{target}/resources/pkg/welcome.html.erb")
    end

    def create_rpm_assets
      return unless options[:rpm_assets]

      copy_file(resource_path('rpm/rpmmacros.erb'), "#{target}/resources/rpm/rpmmacros.erb")
      copy_file(resource_path('rpm/signing.erb'), "#{target}/resources/rpm/signing.erb")
      copy_file(resource_path('rpm/spec.erb'), "#{target}/resources/rpm/spec.erb")
    end
    private

    #
    # The target path to create the Omnibus project.
    #
    # @return [String]
    #
    def target
      @target ||= File.join(File.expand_path(@options[:path]), "omnibus-#{name}")
    end

    #
    # The list of options to pass to the template generators.
    #
    # @return [Hash]
    #
    def template_options
      @template_options ||= { name: name }
    end

    #
    # The path to a vendored resource within Omnibus.
    #
    # @param [String, Array<String>] args
    #   the sub-path to get
    #
    # @return [String]
    #
    def resource_path(*args)
      Omnibus.source_root.join('resources', *args).to_s
    end
  end
end
