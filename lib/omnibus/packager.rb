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
  module Packager
    include Sugarable

    autoload :BFF,      'omnibus/packagers/bff'
    autoload :DEB,      'omnibus/packagers/deb'
    autoload :Makeself, 'omnibus/packagers/makeself'
    autoload :MSI,      'omnibus/packagers/msi'
    autoload :APPX,     'omnibus/packagers/appx'
    autoload :PKG,      'omnibus/packagers/pkg'
    autoload :Solaris,  'omnibus/packagers/solaris'
    autoload :IPS,      'omnibus/packagers/ips'
    autoload :RPM,      'omnibus/packagers/rpm'

    class Platform
      require 'omnibus/packagers/base'

      def initialize(platform_information)
        @platform_info = platform_information
      end

      def self.create(platform_information)
        platform_name = platform_information['platform_family']
        class_name = "#{platform_name.capitalize}Platform"

        begin
          name = Packager.const_get(class_name)
        rescue NameError
          name = DefaultPlatform
        end
        name.new(platform_information)
      end

      # Returns an array of supported packager types for this platform
      # @abstract
      def supported_packagers
        raise AbstractMethodException.new
      end

      protected
      def satisfies_version_constraint?(version_constraint)
        version = @platform_info['platform_version']
        Chef::Sugar::Constraints::Version.new(version).satisfies?(version_constraint)
      end
    end

    class DefaultPlatform < Platform
      include Logging
      require 'omnibus/packagers/makeself'

      def supported_packagers
        platform = @platform_info['platform_family']
        log.warn(log_key) do
          "Could not determine packager for `#{platform}', defaulting to `makeself'!"
        end

        [Makeself]
      end
    end

    class Solaris2Platform < Platform
      require 'omnibus/packagers/solaris'
      require 'omnibus/packagers/ips'
      require 'omnibus/packagers/makeself'

      def supported_packagers
        case
        when satisfies_version_constraint?('>= 5.11')
          [IPS]
        when satisfies_version_constraint?('>= 5.10')
          [Solaris]
        else
          [Makeself]
        end
      end
    end

    class WindowsPlatform < Platform
      require 'omnibus/packagers/msi'
      require 'omnibus/packagers/appx'

      def supported_packagers
        return [MSI, APPX] if satisfies_version_constraint?('>= 6.2')
        [MSI]
      end
    end

    class DebianPlatform < Platform
      require 'omnibus/packagers/DEB'

      def supported_packagers
        [DEB]
      end
    end

    class FedoraPlatform < Platform
      require 'omnibus/packagers/RPM'

      def supported_packagers
        [RPM]
      end
    end

    class SusePlatform < Platform
      require 'omnibus/packagers/RPM'

      def supported_packagers
        [RPM]
      end
    end

    class RhelPlatform < Platform
      require 'omnibus/packagers/RPM'

      def supported_packagers
        [RPM]
      end
    end

    class WrlinuxPlatform < Platform
      require 'omnibus/packagers/RPM'

      def supported_packagers
        [RPM]
      end
    end

    class AixPlatform < Platform
      require 'omnibus/packagers/BFF'

      def supported_packagers
        [BFF]
      end
    end

    class Mac_os_xPlatform < Platform
      require 'omnibus/packagers/PKG'

      def supported_packagers
        [PKG]
      end
    end

    #
    # Determine the packager(s) for the current system. This method returns the
    # class, not an instance of the class.
    #
    # @example
    #   Packager.for_current_system #=> [Packager::RPM]
    #
    # @return [[~Packager::Base]]
    #
    def for_current_system
      Platform.create(Ohai).supported_packagers
    end
    module_function :for_current_system
  end
end
