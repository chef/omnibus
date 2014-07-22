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

require 'json'

module Omnibus
  class Package
    class Metadata
      class << self
        #
        # Generate a +metadata.json+ from the given package and data hash.
        #
        # @param [Package] package
        #   the package for this metadata
        # @param [Hash] data
        #   the hash of attributes to set in the metadata
        #
        # @return [String]
        #   the path where the metadata was saved on disk
        #
        def generate(package, data = {})
          data = {
            basename:         package.name,
            md5:              package.md5,
            sha1:             package.sha1,
            sha256:           package.sha256,
            sha512:           package.sha512,
            platform:         platform_shortname,
            platform_version: platform_version,
            arch:             arch,
          }.merge(data)

          instance = new(package, data)
          instance.save
          instance.path
        end

        #
        # Load the metadata from disk.
        #
        # @param [Package] package
        #   the package for this metadata
        #
        # @return [Metadata]
        #
        def for_package(package)
          data = File.read(path_for(package))
          hash = JSON.parse(data, symbolize_names: true)

           # Ensure Platform version has been truncated
           if hash[:platform_version] && hash[:platform]
             hash[:platform_version] = truncate_platform_version(hash[:platform_version], hash[:platform])
           end

          # Ensure an interation exists
          hash[:iteration] ||= 1

          new(package, hash)
        rescue Errno::ENOENT
          raise NoPackageMetadataFile.new(package.path)
        end

        #
        # The metadata path that corresponds to the package.
        #
        # @param [Package] package
        #   the package for this metadata
        #
        # @return [String]
        #
        def path_for(package)
          "#{package.path}.metadata.json"
        end

        #
        # The architecture for this machine, as reported from Ohai.
        #
        # @return [String]
        #
        def arch
          Ohai['kernel']['machine']
        end

        #
        # Platform version to be used in package metadata.
        #
        # @return [String]
        #   the platform version
        #
        def platform_version
          truncate_platform_version(Ohai['platform_version'], platform_shortname)
        end

        #
        # Platform name to be used when creating metadata for the artifact.
        # rhel/centos become "el", all others are just platform
        #
        # @return [String]
        #   the platform family short name
        #
        def platform_shortname
          if Ohai['platform_family'] == 'rhel'
            'el'
          else
            Ohai['platform']
          end
        end

        private

        #
        # On certain platforms we don't care about the full MAJOR.MINOR.PATCH platform
        # version. This method will properly truncate the version down to a more human
        # friendly version. This version can also be thought of as a 'marketing'
        # version.
        #
        # @param [String] platform_version
        #   the platform version to truncate
        # @param [String] platform_shortname
        #   the platform shortname. this might be an Ohai-returned platform or
        #   platform family but it also might be a shortname like `el`
        #
        def truncate_platform_version(platform_version, platform)
          case platform
          when 'centos', 'debian', 'fedora', 'freebsd', 'rhel', 'el'
            # Only want MAJOR (e.g. Debian 7)
            platform_version.split('.').first
          when 'aix', 'arch', 'gentoo', 'mac_os_x', 'openbsd', 'slackware', 'solaris2', 'suse', 'ubuntu'
            # Only want MAJOR.MINOR (e.g. Mac OS X 10.9, Ubuntu 12.04)
            platform_version.split('.')[0..1].join('.')
          when 'omnios', 'smartos'
            # Only want MAJOR (e.g OmniOS r151006, SmartOS 20120809T221258Z)
            platform_version.split('.').first
          when 'windows'
            # Windows has this really awesome "feature", where their version numbers
            # internally do not match the "marketing" name.
            #
            # Definitively computing the Windows marketing name actually takes more
            # than the platform version. Take a look at the following file for the
            # details:
            #
            #   https://github.com/opscode/chef/blob/master/lib/chef/win32/version.rb
            #
            # As we don't need to be exact here the simple mapping below is based on:
            #
            #  http://www.jrsoftware.org/ishelp/index.php?topic=winvernotes
            #
            case platform_version
            when '5.0.2195', '2000'   then '2000'
            when '5.1.2600', 'xp'     then 'xp'
            when '5.2.3790', '2003r2' then '2003r2'
            when '6.0.6001', '2008'   then '2008'
            when '6.1.7600', '7'      then '7'
            when '6.1.7601', '2008r2' then '2008r2'
            when '6.2.9200', '8'      then '8'
            # The following `when` will never match since Windows 2012's platform
            # version is the same as Windows 8. It's only here for completeness and
            # documentation.
            when '6.2.9200', '2012'   then '2012'
            when /6\.3\.\d+/, '8.1' then '8.1'
            # The following `when` will never match since Windows 2012R2's platform
            # version is the same as Windows 8.1. It's only here for completeness
            # and documentation.
            when /6\.3\.\d+/, '2012r2' then '2012r2'
            else
              raise UnknownPlatformVersion.new(platform, platform_version)
            end
          else
            raise UnknownPlatform.new(platform)
          end
        end
      end

      #
      # Create a new metadata object for the given package and hash data.
      #
      # @param [Package] package
      #   the package for this metadata
      # @param [Hash] data
      #   the hash of attributes to set in the metadata
      #
      def initialize(package, data = {})
        @package = package
        @data    = data.dup.freeze
      end

      #
      # Helper for accessing the information inside the metadata hash.
      #
      # @return [Object]
      #
      def [](key)
        @data[key]
      end

      #
      # The name of this metadata file.
      #
      # @return [String]
      #
      def name
        @name ||= File.basename(path)
      end

      #
      # @see (Metadata.path_for)
      #
      def path
        @path ||= self.class.path_for(@package)
      end

      #
      # Save the file to disk.
      #
      # @return [true]
      #
      def save
        File.open(path, 'w+')  do |f|
          f.write(to_json)
        end

        true
      end

      #
      # The JSON representation of this metadata.
      #
      # @return [String]
      #
      def to_json
        JSON.pretty_generate(@data)
      end
    end

    include Digestable

    attr_reader :path

    #
    # Create a new package from the given path.
    #
    # @param [String] path
    #   the path to the package on disk
    #
    def initialize(path)
      @path = File.expand_path(path)
    end

    #
    # The shortname of this package (the basename of the file).
    #
    # @return [String]
    #
    def name
      @name ||= File.basename(path)
    end

    #
    # The MD5 checksum for this file.
    #
    # @return [String]
    #
    def md5
      @md5 ||= digest(path, :md5)
    end

    #
    # The SHA1 checksum for this file.
    #
    # @return [String]
    #
    def sha1
      @sha1 ||= digest(path, :sha1)
    end

    #
    # The SHA256 checksum for this file.
    #
    # @return [String]
    #
    def sha256
      @sha256 ||= digest(path, :sha256)
    end

    #
    # The SHA512 checksum for this file.
    #
    # @return [String]
    #
    def sha512
      @sha512 ||= digest(path, :sha512)
    end

    #
    # The actual contents of the package.
    #
    # @return [String]
    #
    def content
      @content ||= IO.read(path)
    rescue Errno::ENOENT
      raise NoPackageFile.new(path)
    end

    #
    # The parsed contents of the metadata.
    #
    # @raise [NoPackageMetadataFile] if the {metadata} does not exist
    # @raise [JSON::ParserError] if the JSON is not valid
    #
    # @return [Hash<Symbol, String>]
    #
    def metadata
      @metadata ||= Metadata.for_package(self)
    end

    #
    # Validate the presence of the required components for the package.
    #
    # @raise [NoPackageFile] if the package is not present
    # @raise [NoPackageMetadataFile] if the metadata file is not present
    #
    # @return [true]
    #
    def validate!
      unless File.exist?(path)
        raise NoPackageFile.new(path)
      end

      unless File.exist?(metadata.path)
        raise NoPackageMetadataFile.new(metadata.path)
      end

      true
    end
  end
end
