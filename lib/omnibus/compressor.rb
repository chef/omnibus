#
# Copyright 2014-2018 Chef Software, Inc.
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
  module Compressor
    include Logging

    autoload :Base, "omnibus/compressors/base"
    autoload :DMG,  "omnibus/compressors/dmg"
    autoload :Null, "omnibus/compressors/null"
    autoload :TGZ,  "omnibus/compressors/tgz"

    #
    # Determine the best compressor for the current system. This method returns
    # the class, not an instance of the class.
    #
    # @example
    #   Compressor.for_current_system([:dmg, :tgz]) #=> Packager::DMG
    #
    # @param [Array<Symbol>] compressors
    #   the list of configured compressors
    #
    # @return [~Compressor::Base]
    #
    def for_current_system(compressors)
      family = Ohai["platform_family"]

      if family == "mac_os_x"
        if compressors.include?(:dmg)
          return DMG
        end

        if compressors.include?(:tgz)
          return TGZ
        end
      end

      if compressors.include?(:tgz)
        TGZ
      else
        log.info(log_key) { "No compressor defined for `#{family}'." }
        Null
      end
    end
    module_function :for_current_system
  end
end
