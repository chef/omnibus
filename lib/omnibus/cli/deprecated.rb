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

#
# This file contains the deprecated commands. This class, its references, and
# any associated tests should be removed in the next major release.
#
# @todo Remove in 4.0
#
module Omnibus
  class Command::Base
    class << self
      alias_method :old_dispatch, :dispatch
      def dispatch(m, args, options, config)
        # Handle old --timestamp
        if args.include?('--timestamp') || args.include?('-t')
          Omnibus.log.warn { "The '--timestamp' option has been deprecated! Please use '--override append_timestamp:true' instead." }
          args.delete('--timestamp')
          args.delete('-t')
          args += %w(--override append_timestamp:true)
        end

        # Handle old --no-timestamp
        if args.include?('--no-timestamp')
          Omnibus.log.warn { "The '--no-timestamp' option has been deprecated! Please use '--override append_timestamp:false' instead." }
          args.delete('--no-timestamp')
          args += %w(--override append_timestamp:false)
        end

        #
        # Legacy build command:
        #
        #   $ omnibus build project PROJECT
        #
        if args[0..1] == %w(build project)
          Omnibus.log.debug { 'Detected legacy build command' }
          Omnibus.log.warn  { "The interface for building a project has changed. Please use 'omnibus build hamlet' instead." }
          args.delete_at(1)
          return old_dispatch(m, args, options, config)
        end

        #
        # Legacy software builder:
        #
        #   $ omnibus build software SOFTWARE
        #
        if args[0..1] == %w(build software)
          fail 'Building individual software definitions is no longer supported!'
        end

        #
        # Legacy generator:
        #
        #   $ omnibus project PROJECT
        #
        if args[0] == 'project'
          Omnibus.log.warn { "The project generator has been renamed to 'omnibus new'. Please use 'omnibus new' in the future." }
          args[0] = 'new'
          return old_dispatch(m, args, options, config)
        end

        # Dispatch everything else down the stack
        old_dispatch(m, args, options, config)
      end
    end
  end
end
