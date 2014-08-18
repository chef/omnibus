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
    include Logging

    autoload :Base,     'omnibus/packagers/base'
    autoload :BFF,      'omnibus/packagers/bff'
    autoload :DEB,      'omnibus/packagers/deb'
    autoload :Makeself, 'omnibus/packagers/makeself'
    autoload :MSI,      'omnibus/packagers/msi'
    autoload :PKG,      'omnibus/packagers/pkg'
    autoload :Solaris,  'omnibus/packagers/solaris'
    autoload :RPM,      'omnibus/packagers/rpm'

    # TODO - this is really a "compressor"
    autoload :MacDmg, 'omnibus/packagers/mac_dmg'

    #
    # The list of Ohai platform families mapped to the respective packager
    # class.
    #
    # @return [Hash<String, Class>]
    #
    PLATFORM_PACKAGER_MAP = {
      'debian'   => DEB,
      'fedora'   => RPM,
      'rhel'     => RPM,
      'aix'      => BFF,
      'solaris2' => Solaris,
      'windows'  => MSI,
      'mac_os_x' => PKG,
    }.freeze

    #
    # Determine the packager for the current system. This method returns the
    # class, not an instance of the class.
    #
    # @example
    #   Packager.for_current_system #=> Packager::RPM
    #
    # @return [~Packager::Base]
    #
    def for_current_system
      family = Ohai['platform_family']

      if klass = PLATFORM_PACKAGER_MAP[family]
        klass
      else
        log.warn(log_key) do
          "Could not determine packager for `#{family}', defaulting " \
          "to `makeself'!"
        end

        Makeself
      end
    end
    module_function :for_current_system
  end
end
