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
    end

    build do
      create_volume_icon
      create_compressed_dmg
      set_dmg_icon
      verify_dmg
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

      existing_disks = shellout!("mount | grep \"/Volumes/#{volume_name}\" | awk '{print $1}'")
      existing_disks.stdout.lines.each do |existing_disk|
        existing_disk.chomp!

        Omnibus.logger.debug(log_key) do
          "Detaching disk `#{existing_disk}' before starting dmg packaging."
        end

        shellout!("hdiutil detach '#{existing_disk}'")
      end
    end

    #
    # Create the icon for the volume using sips.
    #
    # @return [void]
    #
    def create_volume_icon
      log.info(log_key) { "Creating volume icon" }

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
        EOH
      end
    end

    #
    # Create a compressed dmg.
    #
    def create_compressed_dmg
      log.info(log_key) { "Creating compressed dmg" }

      shellout! <<-EOH.gsub(/^ {8}/, "")
        pip install dmgbuild==1.6.5
        dmgbuild \\
          --detach-retries=5 \\
          --settings="#{resource_path('settings.py')}" \\
          -Dbackground="#{resource_path('background.png')}" \\
          -Dpkg="#{packager.package_path}" \\
          -Dpkg_position="#{pkg_position}" \\
          -Dvolume_icon="#{staging_dir}/tmp.icns" \\
          -Dwindow_bounds="#{window_bounds}" \\
          "#{volume_name}" \\
          "#{package_path}"
      EOH
    end

    #
    # Verify checksum on created dmg.
    #
    # @return [void]
    #
    def verify_dmg
      log.info(log_key) { "Verifying dmg" }

      Dir.chdir(staging_dir) do
        shellout! <<-EOH.gsub(/^ {10}/, "")
          hdiutil verify \\
            "#{package_path}" \\
            -puppetstrings
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
