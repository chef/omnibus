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
  class Compressor::DMG < Compressor::Base
    id :dmg

    setup do
      # Clean any previously mounted disks
      clean_disks

      # Create the resources directory
      create_directory(resources_dir)

      # Copy the compiled pkg into the dmg
      copy_file(packager.package_path, "#{resources_dir}/")

      # Copy support files
      support = create_directory("#{resources_dir}/.support")
      copy_file(resource_path("background.png"), "#{support}/background.png")
    end

    build do
      create_writable_dmg
      attach_dmg
      # Give some time to the system so attached dmg shows up in Finder
      sleep 5
      set_volume_icon
      prettify_dmg
      compress_dmg
      set_dmg_icon
    end

    #
    # @!group DSL methods
    # --------------------------------------------------

    #
    # Set or return the starting x,y and ending x,y positions for the created
    # DMG window.
    #
    # @example
    #   window_bounds "100, 100, 750, 600"
    #
    # @param [String] val
    #   the DMG window bounds
    #
    # @return [String]
    #   the DMG window bounds
    #
    def window_bounds(val = NULL)
      if null?(val)
        @window_bounds || "100, 100, 750, 600"
      else
        @window_bounds = val
      end
    end
    expose :window_bounds

    #
    # Set or return the starting x,y position where the .pkg file should live
    # in the DMG window.
    #
    # @example
    #   pkg_position "535, 50"
    #
    # @param [String] val
    #   the PKG position inside the DMG
    #
    # @return [String]
    #   the PKG position inside the DMG
    #
    def pkg_position(val = NULL)
      if null?(val)
        @pkg_position || "535, 50"
      else
        @pkg_position = val
      end
    end
    expose :pkg_position

    #
    # @!endgroup
    # --------------------------------------------------

    #
    # The path where the MSI resources will live.
    #
    # @return [String]
    #
    def resources_dir
      File.expand_path("#{staging_dir}/Resources")
    end

    #
    # Cleans any previously left over mounted disks.
    #
    # We are trying to detach disks that look like:
    #
    #   /dev/disk1s1 on /Volumes/chef (hfs, local, nodev, nosuid, read-only, noowners, quarantine, mounted by serdar)
    #   /dev/disk2s1 on /Volumes/chef 1 (hfs, local, nodev, nosuid, read-only, noowners, quarantine, mounted by serdar)
    #
    # @return [void]
    #
    def clean_disks
      log.info(log_key) { "Cleaning previously mounted disks" }

      existing_disks = shellout!("mount | grep /Volumes/#{volume_name} | awk '{print $1}'")
      existing_disks.stdout.lines.each do |existing_disk|
        existing_disk.chomp!

        Omnibus.logger.debug(log_key) do
          "Detaching disk `#{existing_disk}' before starting dmg packaging."
        end

        shellout!("hdiutil detach '#{existing_disk}'")
      end
    end

    #
    # Create a writable dmg we can put assets on.
    #
    def create_writable_dmg
      log.info(log_key) { "Creating writable dmg" }

      shellout! <<-EOH.gsub(/^ {8}/, "")
        hdiutil create \\
          -srcfolder "#{resources_dir}" \\
          -volname "#{volume_name}" \\
          -fs HFS+ \\
          -fsargs "-c c=64,a=16,e=16" \\
          -format UDRW \\
          -size 512000k \\
          "#{writable_dmg}"
      EOH
    end

    #
    # Attach the dmg, storing a reference to the device for later use.
    #
    # @return [String]
    #   the name of the attached device
    #
    def attach_dmg
      @device ||= Dir.chdir(staging_dir) do
        log.info(log_key) { "Attaching dmg as disk" }

        cmd = shellout! <<-EOH.gsub(/^ {10}/, "")
          hdiutil attach \\
            -readwrite \\
            -noverify \\
            -noautoopen \\
            "#{writable_dmg}" | egrep '^/dev/' | sed 1q | awk '{print $1}'
        EOH

        cmd.stdout.strip
      end
    end

    #
    # Create the icon for the volume using sips.
    #
    # @return [void]
    #
    def set_volume_icon
      log.info(log_key) { "Setting volume icon" }

      icon = resource_path("icon.png")

      Dir.chdir(staging_dir) do
        shellout! <<-EOH.gsub(/^ {10}/, "")
          # Generate the icns
          mkdir tmp.iconset
          sips -z 16 16     #{icon} --out tmp.iconset/icon_16x16.png
          sips -z 32 32     #{icon} --out tmp.iconset/icon_16x16@2x.png
          sips -z 32 32     #{icon} --out tmp.iconset/icon_32x32.png
          sips -z 64 64     #{icon} --out tmp.iconset/icon_32x32@2x.png
          sips -z 128 128   #{icon} --out tmp.iconset/icon_128x128.png
          sips -z 256 256   #{icon} --out tmp.iconset/icon_128x128@2x.png
          sips -z 256 256   #{icon} --out tmp.iconset/icon_256x256.png
          sips -z 512 512   #{icon} --out tmp.iconset/icon_256x256@2x.png
          sips -z 512 512   #{icon} --out tmp.iconset/icon_512x512.png
          sips -z 1024 1024 #{icon} --out tmp.iconset/icon_512x512@2x.png
          iconutil -c icns tmp.iconset

          # Copy it over
          cp tmp.icns "/Volumes/#{volume_name}/.VolumeIcon.icns"

          # Source the icon
          SetFile -a C "/Volumes/#{volume_name}"
        EOH
      end
    end

    #
    # Use Applescript to setup the DMG with pretty logos and colors.
    #
    # @return [void]
    #
    def prettify_dmg
      log.info(log_key) { "Making the dmg all pretty and stuff" }

      render_template(resource_path("create_dmg.osascript.erb"),
        destination: "#{staging_dir}/create_dmg.osascript",
        variables: {
          volume_name:   volume_name,
          pkg_name:      packager.package_name,
          window_bounds: window_bounds,
          pkg_position:  pkg_position,
        }
      )

      Dir.chdir(staging_dir) do
        shellout! <<-EOH.gsub(/^ {10}/, "")
          osascript "#{staging_dir}/create_dmg.osascript"
        EOH
      end
    end

    #
    # Compress the dmg using hdiutil and zlib.
    #
    # @return [void]
    #
    def compress_dmg
      log.info(log_key) { "Compressing dmg" }

      Dir.chdir(staging_dir) do
        shellout! <<-EOH.gsub(/^ {10}/, "")
          chmod -Rf go-w /Volumes/#{volume_name}
          sync
          hdiutil detach "#{@device}"
          hdiutil convert \\
            "#{writable_dmg}" \\
            -format UDZO \\
            -imagekey \\
            zlib-level=9 \\
            -o "#{package_path}"
          rm -rf "#{writable_dmg}"
        EOH
      end
    end

    #
    # Set the dmg icon to our custom icon.
    #
    # @return [void]
    #
    def set_dmg_icon
      log.info(log_key) { "Setting dmg icon" }

      Dir.chdir(staging_dir) do
        shellout! <<-EOH.gsub(/^ {10}/, "")
          # Convert the png to an icon
          sips -i "#{resource_path('icon.png')}"

          # Extract the icon into its own resource
          DeRez -only icns "#{resource_path('icon.png')}" > tmp.rsrc

          # Append the icon reosurce to the DMG
          Rez -append tmp.rsrc -o "#{package_path}"

          # Source the icon
          SetFile -a C "#{package_path}"
        EOH
      end
    end

    # @see Base#package_name
    def package_name
      extname = File.extname(packager.package_name)
      packager.package_name.sub(extname, ".dmg")
    end

    # The path to the writable dmg on disk.
    #
    # @return [String]
    def writable_dmg
      File.expand_path("#{staging_dir}/#{project.name}-writable.dmg")
    end

    #
    # The name of the volume to create. By defauly, this is the project's
    # friendly name.
    #
    # @return [String]
    #
    def volume_name
      project.friendly_name
    end
  end
end
