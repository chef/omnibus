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

    class << self
      #
      # Set the source root for Thor.
      #
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
      template('project.rb.erb', "#{target}/config/projects/#{name}.rb", template_options)
    end

    def create_example_software_definitions
      template('software/c-example.rb.erb', "#{target}/config/software/c-example.rb", template_options)
      template('software/erlang-example.rb.erb', "#{target}/config/software/erlang-example.rb", template_options)
      template('software/ruby-example.rb.erb', "#{target}/config/software/ruby-example.rb", template_options)
    end

    def create_kitchen_files
      template('.kitchen.local.yml.erb', "#{target}/.kitchen.local.yml", template_options)
      template('.kitchen.yml.erb', "#{target}/.kitchen.yml", template_options)
      template('Berksfile.erb', "#{target}/Berksfile", template_options)
    end

    def create_package_scripts
      %w(makeselfinst preinst prerm postinst postrm).each do |package_script|
        script_path = "#{target}/package-scripts/#{name}/#{package_script}"
        template("package_scripts/#{package_script}.erb", script_path, template_options)

        # #nsure the package script is executable
        chmod(script_path, 0755)
      end
    end

    def create_pkg_assets
      template('pkg/license.html.erb', "#{target}/files/pkg/Resources/license.html", template_options)
      template('pkg/welcome.html.erb', "#{target}/files/pkg/Resources/welcome.html", template_options)
      copy_file('pkg/background.png', "#{target}/files/pkg/Resources/background.png")
    end

    def create_dmg_assets
      copy_file('mac_dmg/background.png', "#{target}/files/mac_dmg/Resources/background.png")
      copy_file('mac_dmg/icon.png', "#{target}/files/mac_dmg/Resources/icon.png")
    end

    def create_windows_assets
      # These ERB files are actually rendered as ERB files on the target system
      # because the parameters are resolved at the build time for localization
      # and parameters files.
      copy_file('windows_msi/localization-en-us.wxl.erb', "#{target}/files/windows_msi/Resources/localization-en-us.wxl.erb")
      copy_file('windows_msi/parameters.wxi.erb', "#{target}/files/windows_msi/Resources/parameters.wxi.erb")

      template('windows_msi/source.wxs.erb', "#{target}/files/windows_msi/Resources/source.wxs", template_options)

      copy_file('windows_msi/assets/LICENSE.rtf', "#{target}/files/windows_msi/Resources/assets/LICENSE.rtf")
      copy_file('windows_msi/assets/banner_background.bmp', "#{target}/files/windows_msi/Resources/assets/banner_background.bmp")
      copy_file('windows_msi/assets/dialog_background.bmp', "#{target}/files/windows_msi/Resources/assets/dialog_background.bmp")
      copy_file('windows_msi/assets/project.ico', "#{target}/files/windows_msi/Resources/assets/project.ico")
      copy_file('windows_msi/assets/project_16x16.ico', "#{target}/files/windows_msi/Resources/assets/project_16x16.ico")
      copy_file('windows_msi/assets/project_32x32.ico', "#{target}/files/windows_msi/Resources/assets/project_32x32.ico")
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
      @template_options ||= {
        name: name,
        install_dir: "/opt/#{name}",
      }
    end
  end
end
