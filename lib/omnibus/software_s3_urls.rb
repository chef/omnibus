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
  module SoftwareS3URLs
    class InsufficientSpecification < ArgumentError
      def initialize(key, package)
        @key, @package = key, package
      end

      def to_s
        "Software must specify a #{@key} to cache it in S3 (#{@package})!"
      end
    end

    def config
      Omnibus.config
    end

    def url_for(software)
      "http://#{config.s3_bucket}.s3.amazonaws.com/#{key_for_package(software)}"
    end

    private

    def key_for_package(package)
      return @key_for_package if @key_for_package

      package.name     || fail(InsufficientSpecification.new(:name, package))
      package.version  || fail(InsufficientSpecification.new(:version, package))
      package.checksum || fail(InsufficientSpecification.new(:checksum, package))

      @key_for_package = "#{package.name}-#{package.version}-#{package.checksum}"
      @key_for_package
    end
  end
end
