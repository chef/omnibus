#
# Copyright 2012-2014 Chef Software, Inc.
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

require 'ohai'

class Mash
  #
  # @todo Remove in the next major release
  #
  # Ohai 7 removed the ability to access Ohai attributes via dot notation. This
  # temporary monkey patch provides the ability for users to still use the old
  # dot notation, while printing out a deprecation error.
  #
  def method_missing(m, *args, &block)
    if key?(m)
      Omnibus.logger.deprecated('Ohai') do
        "Ohai.#{m}. Please use Ohai['#{m}'] instead."
      end

      fetch(m)
    else
      super
    end
  end
end

module Omnibus
  class Ohai
    PLUGINS = [
      'cpu',
      'kernel',
      'os',
      'platform',
    ].freeze

    class << self
      def method_missing(m, *args, &block)
        ohai.send(m, *args, &block)
      end

      private

      def ohai
        @ohai ||= ::Ohai::System.new.tap { |o| o.all_plugins(PLUGINS) }
      end
    end
  end
end

module Omnibus
  class OhaiWithWarning < Ohai
    include Logging

    class << self
      def method_missing(m, *args, &block)
        bad_boy = caller[2]

        unless warned[bad_boy]
          log.deprecated('OHAI') do
            "OHAI constant. Please use Ohai instead: #{bad_boy}"
          end
          warned[bad_boy] = true
        end

        Ohai.send(m, *args, &block)
      end

      def warned
        @warned ||= {}
      end
    end
  end
end

#
# @todo remove in the next major release
#
OHAI = Omnibus::OhaiWithWarning
