#
# Copyright 2014, Chef Software, Inc.
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

    argument :path,
      banner: 'PATH',
      aliases: '-p',
      desc: 'The path to create the Omnibus project',
      type: :string,
      required: true

    #
    # Set the source root for Thor.
    #
    def self.source_root
      File.expand_path('../generator_files', __FILE__)
    end

    def create_project_files
      template('Gemfile.erb', "#{path}/Gemfile", template_options)
      template('gitignore.erb', "#{path}/.gitignore", template_options)
      template('README.md.erb', "#{path}/README.md", template_options)
      template('omnibus.rb.example.erb', "#{path}/omnibus.rb.example", template_options)
    end

    def create_project_definition
      template('project.rb.erb', "#{path}/config/projects/#{name}.rb", template_options)
    end

    def create_example_software_definitions
      template('software/c-example.rb.erb', "#{path}/config/software/c-example.rb", template_options)
      template('software/erlang-example.rb.erb', "#{path}/config/software/erlang-example.rb", template_options)
      template('software/ruby-example.rb.erb', "#{path}/config/software/ruby-example.rb", template_options)
    end

    def create_kitchen_files
      template('.kitchen.local.yml.erb', "#{path}/.kitchen.local.yml", template_options)
      template('.kitchen.yml.erb', "#{path}/.kitchen.yml", template_options)
      template('Berksfile.erb', "#{path}/Berksfile", template_options)
    end

    def create_package_scripts
      %w[makeselfinst preinst prerm postinst postrm].each do |package_script|
        script_path = "#{path}/package-scripts/#{name}/#{package_script}"
        template("package_scripts/#{package_script}.erb", script_path, template_options)

        # #nsure the package script is executable
        chmod(script_path, 0755)
      end
    end

    def create_pkg_assets
      template('mac_pkg/license.html.erb', "#{path}/files/mac_pkg/Resources/license.html", template_options)
      template('mac_pkg/welcome.html.erb', "#{path}/files/mac_pkg/Resources/welcome.html", template_options)
      copy_file('mac_pkg/background.png', "#{path}/files/mac_pkg/Resources/background.png")
    end

    def create_dmg_assets
      copy_file('mac_dmg/background.png', "#{path}/files/mac_dmg/Resources/background.png")
      copy_file('mac_dmg/icon.png', "#{path}/files/mac_dmg/Resources/icon.png")
    end

    private

    #
    # The name of the omnibus project. This is inferred from project path.
    #
    # @return [String]
    #
    def name
      @name ||= File.basename(File.expand_path(path))
    end

    #
    # The list of options to pass to the template generators.
    #
    # @return [Hash]
    #
    def template_options
      @template_options ||= {
        name: name,
        install_path: "/opt/#{name}",
      }
    end
  end
end
