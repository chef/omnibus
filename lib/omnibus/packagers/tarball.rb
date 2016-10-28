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
  class Packager::Tarball < Packager::Base
    # @return [Hash]
    SCRIPT_MAP = {
      # Default Omnibus naming
      postinst: "postinst",
    }.freeze

    id :tarball

    setup do
      # Copy the full-stack installer into our scratch directory, accounting for
      # any excluded files.
      #
      # /opt/hamlet => /tmp/daj29013
      FileSyncer.sync(project.install_dir, staging_dir, exclude: exclusions)
    end

    build do
      # Create the tarball archive
      create_tarball_package
    end

    # @see Base#package_name
    def package_name
      "#{project.package_name}-#{project.build_version}_#{project.build_iteration}.#{safe_architecture}.tgz"
    end

    #
    # Run the actual tarball command, publishing the generated package.
    #
    # @return [void]
    #
    def create_tarball_package
      log.info(log_key) { "Creating tarball package" }

      Dir.chdir(staging_dir) do
        shellout! "tar -cz -f #{package_name} -C #{staging_dir}"
      end
    end

    #
    # The architecture for this tarball package.
    #
    # @return [String]
    #
    def safe_architecture
      Ohai["kernel"]["machine"]
    end
  end
end
