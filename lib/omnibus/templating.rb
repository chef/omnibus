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

require 'erb'

module Omnibus
  module Templating
    include Logging
    extend self

    #
    # Render an erb template on disk at +source+. If the +:destination+ option
    # is given, the file will be rendered at +:destination+, otherwise the
    # template is rendered next to +source+, removing the 'erb' extension of the
    # template.
    #
    # @param [String] source
    #   the path on disk where the ERB template lives
    #
    # @option options [String] :destination
    #   the destination where the rendered ERB should reside
    # @option options [Fixnum] :mode
    #   the mode of the rendered file
    # @option options [Hash] :variables
    #   the list of variables to pass to the template
    #
    def render_template(source, options = {})
      destination = options.delete(:destination) || source.chomp('.erb')

      mode      = options.delete(:mode) || 0644
      variables = options.delete(:variables) || {}

      log.info(log_key) { "Rendering `#{source}' to `#{destination}'" }

      unless options.empty?
        raise ArgumentError,
          "Unknown option(s): #{options.keys.map(&:inspect).join(', ')}"
      end

      template = ERB.new(File.read(source), nil, '-')
      struct   = Struct.new(*variables.keys).new(*variables.values)
      result   = template.result(struct.instance_eval { binding })

      File.open(destination, 'w') do |file|
        file.write(result)
      end

      File.chmod(mode, destination)

      true
    end
  end
end
