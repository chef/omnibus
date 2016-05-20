#
# Copyright 2014 Chef Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the ''License");
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

require "rubygems/package"
require "zlib"

module Omnibus
  class Compressor::TGZ < Compressor::Base
    id :tgz

    setup do
      # Copy the compiled package (.deb, .rpm, .pkg) into the staging directory
      copy_file(packager.package_path, "#{staging_dir}/")
    end

    build do
      write_tgz
    end

    #
    # @!group DSL methods
    # --------------------------------------------------

    #
    # Set or return the level of compression to use when generating the zipped
    # tarball. Default: max compression.
    #
    # @example
    #   compression_level 9
    #
    # @param [Fixnum] val
    #   the compression level to use
    #
    # @return [Fixnum]
    #
    def compression_level(val = NULL)
      if null?(val)
        @compression_level || Zlib::BEST_COMPRESSION
      else
        unless val.is_a?(Integer)
          raise InvalidValue.new(:compression_level, "be an Integer")
        end

        unless val.between?(1, 9)
          raise InvalidValue.new(:compression_level, "be between 1-9")
        end

        @compression_level = val
      end
    end
    expose :compression_level

    #
    # @!endgroup
    # --------------------------------------------------

    #
    # @see Base#package_name
    #
    def package_name
      "#{packager.package_name}.tar.gz"
    end

    #
    # Write the tar.gz to disk, reading in 1024 bytes at a time to reduce
    # memory usage.
    #
    # @return [void]
    #
    def write_tgz
      # Grab the contents of the gzipped tarball for reading
      contents = gzipped_tarball

      # Write the .tar.gz into the staging directory
      File.open("#{staging_dir}/#{package_name}", "wb") do |tgz|
        while chunk = contents.read(1024)
          tgz.write(chunk)
        end
      end

      # Copy the .tar.gz into the package directory
      FileSyncer.glob("#{staging_dir}/*.tar.gz").each do |tgz|
        copy_file(tgz, Config.package_dir)
      end
    end

    #
    # Create an in-memory tarball from the given packager.
    #
    # @return [StringIO]
    #
    def tarball
      tarfile = StringIO.new("")
      Gem::Package::TarWriter.new(tarfile) do |tar|
        path = "#{staging_dir}/#{packager.package_name}"
        name = packager.package_name
        mode = File.stat(path).mode

        tar.add_file(name, mode) do |tf|
          File.open(path, "rb") do |file|
            tf.write(file.read)
          end
        end
      end

      tarfile.rewind
      tarfile
    end

    #
    # Create the gzipped tarball. See {#tarball} for how the tarball is
    # constructed. This method uses maximum gzip compression, unless the user
    # specifies a different compression level.
    #
    # @return [StringIO]
    #
    def gzipped_tarball
      gz = StringIO.new("")
      z = Zlib::GzipWriter.new(gz, compression_level)
      z.write(tarball.string)
      z.close

      # z was closed to write the gzip footer, so
      # now we need a new StringIO
      StringIO.new(gz.string)
    end
  end
end
