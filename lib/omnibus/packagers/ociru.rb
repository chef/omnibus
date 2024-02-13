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

require "find"
require "json"
require "pathname"
require "omnibus/packagers/windows_base"
require "fileutils"

module Omnibus
  class Packager::OCIRU < Packager::Base
    id :ociru

    build do
      case compression_algorithm
      when "gzip"
        tar_flag = "-z"
        ext = "gz"
      when "xz"
        tar_flag = "-J"
        ext = "xz"
      when "ztsd"
        tar_flag = "-I zstd"
        ext = "zst"
      else
        raise ArgumentError, "Unknown archive format '#{compression_algorithm}'"
      end
      intermediate_pkg_name = "package.tar.#{ext}"
      # create the payload directory, copy the install_dir and extra files to it
      payload_dir = File.join(staging_dir, "payload")
      install_dir = File.join(payload_dir, project.install_dir)
      FileSyncer.sync(project.install_dir, install_dir, exclude: exclusions)
      project.extra_package_files.each do |file|
        if File.directory?(file)
          destination = File.join(payload_dir, file)
          FileUtils.makedirs(destination)
          FileSyncer.sync(file, destination)
        else
          destination = File.join(payload_dir, File.dirname(file))
          FileUtils.makedirs(destination)
          FileUtils.cp(file, destination, preserve: true)
        end
      end
      fl = filelist(payload_dir)

      # Pass compression options regardless of the used algorithm, worst case they will get ignored
      compress_env = { "XZ_OPT" => "-T#{compression_threads} -#{compression_level}" }

      # create the archive
      archive_file = windows_safe_path(staging_dir, intermediate_pkg_name)
      cmd = <<-EOH.split.join(" ").squeeze(" ").strip
        tar -C #{payload_dir} -c #{tar_flag}
        -f #{archive_file}
        .
      EOH
      measure("Compressing OCI") do
        shellout!(cmd, environment: compress_env)
      end
      FileUtils.rm_rf(payload_dir)

      # move it to the proper location in the blobs directory
      digest = Digest::SHA256.file(archive_file).hexdigest
      sha256_path = File.join(staging_dir, "blobs", "sha256")
      blob_path = File.join(sha256_path, digest)
      FileUtils.makedirs(sha256_path)
      FileUtils.mv(archive_file, blob_path)

      # create all the json metadata files
      create_metadata(digest, File.size(blob_path), fl)

      # create the final package
      package_file = windows_safe_path(Config.package_dir, package_name)
      cmd = <<-EOH.split.join(" ").squeeze(" ").strip
        tar -C #{staging_dir} -c #{tar_flag}
        -f #{package_file}
        .
      EOH
      compress_env = { "XZ_OPT" => "-T#{compression_threads} -1" }
      measure("Final package compression") do
        shellout!(cmd, environment: compress_env)
      end
    end

    def create_metadata(archive_sha256, archive_size, filelist)
      create_oci_layout
      config_sha256, config_size = create_config(filelist)
      manifest_sha256, manifest_size = create_manifest(archive_sha256, archive_size, config_sha256, config_size)
      create_index_json(manifest_sha256, manifest_size)
    end

    def create_config(filelist)
      json = {
        name: project.package_name,
        version: "#{project.build_version}-#{project.build_iteration}",
        os: oci_os,
        arch: oci_architecture,
        license: project.license,
        license_file: project.license_file_path,
        license_3rd_party: project.third_party_licenses_path,
        special_files: special_files,
        filelist: filelist,
      }
      write_json_file(json, "config.json", true)
    end

    def create_manifest(archive_sha256, archive_size, config_sha256, config_size)
      json = {
        "schemaVersion": 2,
        "mediaType": "application/vnd.oci.image.manifest.v1+json",
        "artifactType": "application/vnd.datadoghq.pkg",
        "config": {
          "mediaType": "application/vnd.datadoghq.pkgmetadata.v1+json",
          "digest": "sha256:#{config_sha256}",
          "size": config_size
        },
        "layers": [
          {
            "mediaType": "application/vnd.oci.image.layer.v1.tar+#{compression_algorithm}",
            "digest": "sha256:#{archive_sha256}",
            "size": archive_size
          }
        ]
      }
      write_json_file(json, "manifest.json", true)
    end

    def create_oci_layout
      json = {
        "imageLayoutVersion" => "1.0.0",
      }
      write_json_file(json, "oci-layout")
    end

    def create_index_json(manifest_sha256, manifest_size)
      json = {
        "schemaVersion": 2,
        "mediaType": "application/vnd.oci.image.index.v1+json",
        "manifests": [
          {
            "mediaType": "application/vnd.oci.image.manifest.v1+json",
            "size": manifest_size,
            "digest": "sha256:#{manifest_sha256}",
            "platform": {
              "architecture": oci_architecture,
              "os": oci_os,
            },
          },
        ],
        "annotations": {
          "com.datadoghq.package.name": project.package_name,
          "com.datadoghq.package.version": "#{project.build_version}-#{project.build_iteration}",
          "com.datadoghq.package.license": project.license,
        }
      }
      write_json_file(json, "index.json")
    end

    def write_json_file(json, filename, move_to_blobs = false)
      fname = File.join(staging_dir, filename)
      File.open(fname, "w") do |f|
        f.write(json.to_json)
      end

      digest = Digest::SHA256.file(fname).hexdigest
      size = File.size(fname)
      if move_to_blobs
        sha256_path = File.join(staging_dir, "blobs", "sha256")
        blob_path = File.join(sha256_path, digest)
        FileUtils.mv(fname, blob_path)
      end

      return digest, size
    end

    def package_name
      case compression_algorithm
      when "gzip"
        ext = "gz"
      when "xz"
        ext = "xz"
      when "ztsd"
        ext = "zst"
      else
        raise ArgumentError, "Unknown archive format '#{compression_algorithm}'"
      end
      "#{project.package_name}_#{project.build_version}-#{project.build_iteration}_oci_#{oci_architecture}.tar.#{ext}"
    end

    # The remote_updater packager doesn't support debug packaging
    def debug_build?
      false
    end

    def special_files(val = NULL)
      if null?(val)
        @special_files
      else
        @special_files = val
      end
    end
    expose :special_files

    def filelist(payload_dir)
      nb_workers = 8
      results = Array.new(nb_workers)

      process_files = Proc.new do |file_slice, index|
        filelist = {}
        file_slice.each do |path|
          installed_path = Pathname.new(path).relative_path_from(Pathname.new(payload_dir)).to_s
          stat = File.stat(path)
          filelist["/#{installed_path}"] = {
            "perms": stat.mode.to_s(8)[-4..-1],
          }
          unless stat.directory? or stat.symlink?
            filelist["/#{installed_path}"]["digest"] = "sha256:#{Digest::SHA256.file(path).hexdigest}"
          end
        end
        results[index] = filelist
      end

      measure("Checksuming all files") do
        pool = ThreadPool.new(nb_workers) do |pool|
          to_hash = []
          Find.find(payload_dir) do |path|
            to_hash.push(path)
          end
          slices = to_hash.each_slice((to_hash.size / nb_workers.to_f).round).to_a
          slices.each_with_index do |s, i|
            pool.schedule(s, i, &process_files)
          end
        end
      end

      filelist = {}
      results.each do |r|
        unless r.nil?
          filelist.merge(r)
        end
      end
      filelist.delete("/.")

      filelist
    end

    def oci_os
      @safe_os = case Ohai["platform_family"]
                 when "windows" then "windows"
                 when "mac_os_x" then "darwin"
                 else "linux"
                 end
    end

    def oci_architecture
      val = shellout!("uname --processor").stdout.strip

      val = case val
            when "x86_64", "x64", "amd64" then "amd64"
            when "arm64", "aarch64" then "arm64"
            when "armv7l" then "arm"
            else raise ArgumentError, "Unknown architecture '#{val}'"
            end

      @oci_architecture = val
    end

    def compression_algorithm(val = nil)
      if val.nil?
        @compression_algorithm || "xz"
      else
        if val != "gzip" && val != "xz" && val != "ztsd"
          raise InvalidValue.new(:compression_algorithm, 'be either gzip, xz or zstd')
        end

        @compression_algorithm = val
      end
    end
    expose :compression_algorithm

    def compression_threads(val = nil)
      if val.nil?
        @compression_threads || 1
      else
        unless val > 0 && val < 32
          raise InvalidValue.new(:compression_threads, 'be a stricly positive and lower than 32 Integer')
        end

        @compression_threads = val
      end
    end
    expose :compression_threads

    def compression_level(val = nil)
      if val.nil?
        @compression_level || 6
      else
        unless val >= 0 && val <= 9
          raise InvalidValue.new(:compression_level, 'be an Integer between 0 and 9 included')
        end

        @compression_level = val
      end
    end
    expose :compression_level
  end
end
