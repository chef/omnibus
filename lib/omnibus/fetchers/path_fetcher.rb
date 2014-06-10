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

module Omnibus
  # Fetcher implementation for projects on the filesystem
  class PathFetcher < Fetcher

    include Digestable

    def initialize(software)
      @name = software.name
      @source = software.source
      @project_dir = software.project_dir
      @version = software.version
      super
    end

    def description
      <<-EOH.gsub(/^ {8}/, '').strip
        source path:    #{@source[:path]}
        local location: #{@project_dir}
      EOH
    end

    def rsync
      if Ohai.platform == 'windows'
        # Robocopy's return code is 1 if it succesfully copies over the
        # files and 0 if the files are already existing at the destination
        sync_cmd = "robocopy #{@source[:path]}\\ #{@project_dir}\\ /MIR /S"
        shellout!(sync_cmd, returns: [0, 1])
      else
        sync_cmd = "rsync --delete -a #{@source[:path]}/ #{@project_dir}/"
        shellout!(sync_cmd)
      end
    end

    def clean
      # Here, clean will do the same as fetch: reset source to pristine state
      rsync
    end

    def fetch
      rsync
    end

    def version_for_cache
      @version_for_cache ||= digest_directory(@project_dir, :sha256)
    end

    def fetch_required?
      true
    end
  end
end
