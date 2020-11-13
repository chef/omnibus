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
require "erb" unless defined?(Erb)

module Omnibus
  module Templating
    def self.included(base)
      # This module also requires logging
      base.send(:include, Logging)
    end

    #
    # Render an erb template to a String variable.
    #
    # @return [String]
    #
    # @param [String] source
    #   the path on disk where the ERB template lives
    #
    # @option options [Fixnum] :mode (default: +0644+)
    #   the mode of the rendered file
    # @option options [Hash] :variables (default: +{}+)
    #   the list of variables to pass to the template
    #
    def render_template_content(source, variables = {})
      template = ERB.new(File.read(source), nil, "-")

      struct =
        if variables.empty?
          Struct.new("Empty")
        else
          Struct.new(*variables.keys).new(*variables.values)
        end

      template.result(struct.instance_eval { binding })
    end

    #
    # Render an erb template on disk at +source+. If the +:destination+ option
    # is given, the file will be rendered at +:destination+, otherwise the
    # template is rendered next to +source+, removing the 'erb' extension of the
    # template.
    #
    # @param [String] source
    #   the path on disk where the ERB template lives
    #
    # @option options [String] :destination (default: +source+)
    #   the destination where the rendered ERB should reside
    # @option options [Fixnum] :mode (default: +0644+)
    #   the mode of the rendered file
    # @option options [Hash] :variables (default: +{}+)
    #   the list of variables to pass to the template
    #
    def render_template(source, options = {})
      destination = options.delete(:destination) || source.chomp(".erb")
      mode = options.delete(:mode) || 0644
      variables = options.delete(:variables) || {}

      log.info(log_key) { "Rendering `#{source}' to `#{destination}'" }

      unless options.empty?
        raise ArgumentError,
          "Unknown option(s): #{options.keys.map(&:inspect).join(", ")}"
      end

      # String value returned from #render_template_content
      result = render_template_content(source, variables)

      File.open(destination, "w", mode) do |file|
        file.write(result)
      end

      true
    end
  end
end
