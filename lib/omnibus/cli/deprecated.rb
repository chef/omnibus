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
      include Util

      alias_method :old_dispatch, :dispatch
      def dispatch(m, args, options, config)
        # Handle OMNIBUS_APPEND_TIMESTAMP environment
        if ENV.key?('OMNIBUS_APPEND_TIMESTAMP')
          value = ENV.delete('OMNIBUS_APPEND_TIMESTAMP')

          if truthy?(value)
            warn("The environment variable 'OMNIBUS_APPEND_TIMESTAMP' is deprecated. Please use '--override append_timestamp:true' instead.")
            args += %(--override append_timestamp:true)
          elsif falsey?(value)
            warn("The environment variable 'OMNIBUS_APPEND_TIMESTAMP' is deprecated. Please use '--override append_timestamp:false' instead.")
            args += %(--override append_timestamp:false)
          else
            raise "Unknown value for OMNIBUS_APPEND_TIMESTAMP: #{value.inspect}!"
          end
        end

        # Handle old Config.release_s3_bucket
        if Config.has_key?(:release_s3_bucket)
          warn("The config variable 'release_s3_bucket' is deprecated. Please remove it from your config.")
        end

        # Handle old --timestamp
        if args.include?('--timestamp') || args.include?('-t')
          warn("The '--timestamp' option has been deprecated! Please use '--override append_timestamp:true' instead.")
          args.delete('--timestamp')
          args.delete('-t')
          args += %w(--override append_timestamp:true)
        end

        # Handle old --no-timestamp
        if args.include?('--no-timestamp')
          warn("The '--no-timestamp' option has been deprecated! Please use '--override append_timestamp:false' instead.")
          args.delete('--no-timestamp')
          args += %w(--override append_timestamp:false)
        end

        #
        # Legacy build command:
        #
        #   $ omnibus build project PROJECT
        #
        if args[0..1] == %w(build project)
          warn("The interface for building a project has changed. Please use 'omnibus build hamlet' instead.")
          args.delete_at(1)
          return old_dispatch(m, args, options, config)
        end

        #
        # Legacy software builder:
        #
        #   $ omnibus build software SOFTWARE
        #
        if args[0..1] == %w(build software)
          raise 'Building individual software definitions is no longer supported!'
        end

        #
        # Legacy generator:
        #
        #   $ omnibus project PROJECT
        #
        if args[0] == 'project'
          warn("The project generator has been renamed to 'omnibus new'. Please use 'omnibus new' in the future.")
          args[0] = 'new'
          return old_dispatch(m, args, options, config)
        end

        #
        # Legacy releaser:
        #
        #   $ omnibus release
        #
        if args[0..1] == %w(release package)
          warn("The interface for releasing a project has changed. Please use 'omnibus publish BACKEND [COMAMND]' instead.")
          args[0] = 'publish'
          args.delete('package')
          args.insert(1, 's3')

          if args.include?('--public')
            warn("The '--public' option has been deprecated! Please use '--acl public' instead.")
            args.delete('--public')
            args += %w(--acl public)
          end

          if args.include?('--no-public')
            warn("The '--no-public' option has been deprecated! Please use '--acl private' instead.")
            args.delete('--no-public')
            args += %w(--acl private)
          end

          if Config.has_key?(:release_s3_bucket)
            warn("The config variable 'release_s3_bucket' is deprecated. Please use 'omnibus publish s3 #{Config[:release_s3_bucket]}' instead.")
            args.insert(2, Config[:release_s3_bucket])
          end

          return old_dispatch(m, args, options, config)
        end

        # Dispatch everything else down the stack
        old_dispatch(m, args, options, config)
      end
    end
  end
end
