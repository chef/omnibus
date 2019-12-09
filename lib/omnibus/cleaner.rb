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

require "thor"

module Omnibus
  class Cleaner < Thor::Group
    include Thor::Actions

    namespace :clean

    argument :name,
             banner: "NAME",
             desc: "The name of the Omnibus project",
             type: :string,
             required: true

    class_option :purge,
                 desc: "Purge the packages and caches",
                 type: :boolean,
                 default: false

    def initialize(*)
      super
      @project = Project.load(name)
    end

    def clean_source_dir
      FileSyncer.glob("#{Config.source_dir}/**/*").each(&method(:remove_file))
    end

    def clean_build_dir
      FileSyncer.glob("#{Config.build_dir}/**/*").each(&method(:remove_file))
    end

    def clean_package_dir
      return unless purge?

      FileSyncer.glob("#{Config.package_dir}/**/*").each(&method(:remove_file))
    end

    def clean_cache_dir
      return unless purge?

      FileSyncer.glob("#{Config.cache_dir}/**/*").each(&method(:remove_file))
    end

    def clean_install_dir
      return unless purge?

      remove_file(@project.install_dir)
    end

    private

    def purge?
      !!options[:purge]
    end
  end
end
