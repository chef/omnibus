#
# Copyright 2013-2014 Chef Software, Inc.
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
  module CLI
    class Release < Base
      namespace :release

      option :target,
        short: '-t TARGET',
        long: '--target TARGET',
        default: 'S3',
        description: 'The target backend to release the package'

      desc 'package PATH', 'Upload a single package to S3'
      option :public, type: :boolean, default: false, desc: 'Make S3 object publicly readable'
      def package(path)
        access_policy = options[:public] ? :public_read : :private

        uploader = PackageRelease.new(path, access: access_policy) do |uploaded_item|
          say("Uploaded #{uploaded_item}", :green)
        end
        uploader.release
      end
    end
  end
end
