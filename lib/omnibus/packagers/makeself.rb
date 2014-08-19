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
  class Packager::Makeself < Packager::Base
    id :makeself

    setup do
      # Copy the full-stack installer into our scratch directory, accounting for
      # any excluded files.
      #
      # /opt/hamlet => /tmp/daj29013
      FileSyncer.sync(project.install_dir, staging_dir, exclude: exclusions)
    end

    build do
      # Render the post_extract file
      write_post_extract_file

      # Create the makeself archive
      create_makeself_package
    end

    # @see Base#package_name
    def package_name
      "#{project.name}-#{project.build_version}_#{project.build_iteration}.#{safe_architecture}.run"
    end

    #
    # The path to the makeself script - the default should almost always be
    # fine!
    #
    # @return [String]
    #
    def makeself
      resource_path('makeself.sh')
    end

    #
    # The path to the makeself-header script - the default should almost always
    # be fine!
    #
    # @return [String]
    #
    def makeself_header
      resource_path('makeself-header.sh')
    end

    #
    # Write the post-extraction file that will be executed upon extraction of
    # the makeself file.
    #
    # @return [void]
    #
    def write_post_extract_file
      render_template(resource_path('post_extract.sh.erb'),
        destination: File.join(staging_dir, 'post_extract.sh'),
        mode: 0755,
        variables: {
          name:          project.name,
          friendly_name: project.friendly_name,
          install_dir:   project.install_dir,
        }
      )
    end

    #
    # Run the actual makeself command, publishing the generated package.
    #
    # @return [void]
    #
    def create_makeself_package
      log.info(log_key) { "Creating makeself package" }

      Dir.chdir(staging_dir) do
        shellout! <<-EOH.gsub(/^ {10}/, '')
          #{makeself} \\
            --header "#{makeself_header}" \\
            --gzip \\
            "#{staging_dir}" \\
            "#{package_name}" \\
            "#{project.description}" \\
            "./post_extract.sh"
        EOH
      end

      FileSyncer.glob("#{staging_dir}/*.run").each do |makeself|
        copy_file(makeself, Config.package_dir)
      end
    end

    #
    # The architecture for this makeself package.
    #
    # @return [String]
    #
    def safe_architecture
      Ohai['kernel']['machine']
    end
  end
end
