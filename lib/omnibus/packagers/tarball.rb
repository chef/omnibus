#
# Copyright 2015 Chef Software, Inc.
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
    id :tarball

    setup do
      # Copy the full-stack installer into our scratch directory, accounting for
      # any excluded files.
      #
      # /opt/hamlet => /tmp/daj29013/opt/hamlet
      destination = File.join(staging_dir, project.install_dir)
      FileSyncer.sync(project.install_dir, destination, exclude: exclusions)
    end

    build do
      # Create Tarball
      Dir.chdir(staging_dir) do
        shellout! "tar cf /var/cache/omnibus/pkg/#{package_name} #{project.install_dir}"
      end

    end

    #
    # @!group DSL methods
    # --------------------------------------------------

    #
    # Set or return the vendor who made this package.
    #
    # @example
    #   vendor "Seth Vargo <sethvargo@gmail.com>"
    #
    # @param [String] val
    #   the vendor who make this package
    #
    # @return [String]
    #   the vendor who make this package
    #
    def vendor(val = NULL)
      if null?(val)
        @vendor || 'Omnibus <omnibus@getchef.com>'
      else
        unless val.is_a?(String)
          raise InvalidValue.new(:vendor, 'be a String')
        end

        @vendor = val
      end
    end
    expose :vendor

    #
    # Set or return the license for this package.
    #
    # @example
    #   license "Apache 2.0"
    #
    # @param [String] val
    #   the license for this package
    #
    # @return [String]
    #   the license for this package
    #
    def license(val = NULL)
      if null?(val)
        @license || 'unknown'
      else
        unless val.is_a?(String)
          raise InvalidValue.new(:license, 'be a String')
        end

        @license = val
      end
    end
    expose :license

    #
    # Set or return the priority for this package.
    #
    # @example
    #   priority "extra"
    #
    # @param [String] val
    #   the priority for this package
    #
    # @return [String]
    #   the priority for this package
    #
    def priority(val = NULL)
      if null?(val)
        @priority || 'extra'
      else
        unless val.is_a?(String)
          raise InvalidValue.new(:priority, 'be a String')
        end

        @priority = val
      end
    end
    expose :priority

    #
    # Set or return the section for this package.
    #
    # @example
    #   section "databases"
    #
    # @param [String] val
    #   the section for this package
    #
    # @return [String]
    #   the section for this package
    #
    def section(val = NULL)
      if null?(val)
        @section || 'misc'
      else
        unless val.is_a?(String)
          raise InvalidValue.new(:section, 'be a String')
        end

        @section = val
      end
    end
    expose :section

    #
    # @!endgroup
    # --------------------------------------------------

    #
    # The name of the tarball
    #
    def package_name
      "#{project.package_name}_#{project.build_version}-#{project.build_iteration}.#{Ohai['kernel']['machine']}.tar"
    end
  end
end
