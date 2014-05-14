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
  class Command::Release < Command::Base
    namespace :release

    class_option :target,
      aliases: '-t',
      desc: 'The target backend to release the package',
      default: 'S3'

    method_option :public,
      type: :boolean,
      desc: 'Make S3 object publicly readable',
      default: false
    desc 'package PATH', 'Upload a single package to S3'
    def package(path)
      access_policy = options[:public] ? :public_read : :private

      uploader = PackageRelease.new(path, access: access_policy) do |uploaded_item|
        say("Uploaded #{uploaded_item}", :green)
      end
      uploader.release
    end
  end
end
