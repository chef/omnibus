#
# Copyright:: Copyright (c) 2013 Opscode, Inc.
# License:: Apache License, Version 2.0
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

require 'omnibus/cli/base'
require 'omnibus/cli/application'
require 'omnibus/package_release'
require 'json'

module Omnibus
  module CLI


    class Release < Base

      namespace :release

      def initialize(args, options, config)
        super(args, options, config)
      end

      desc "package PATH", "Upload a single package to S3"
      option :public, :type => :boolean, :default => false, :desc => "Make S3 object publicly readable"
      def package(path)
        access_policy = options[:public] ? :public_read : :private

        uploader = PackageRelease.new(path, :access => access_policy) do |uploaded_item|
          say("Uploaded #{uploaded_item}", :green)
        end
        uploader.release
      end

    end
  end
end

