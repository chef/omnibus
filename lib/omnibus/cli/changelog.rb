#
# Copyright 2015 Chef Software, Inc.
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

require 'omnibus/changelog'
require 'omnibus/changelog_printer'
require 'omnibus/manifest_diff'
require 'omnibus/semantic_version'

module Omnibus
  class Command::ChangeLog < Command::Base
    namespace :changelog

    #
    # Generate a Changelog
    #
    #   $ omnibus changelog generate
    #
    method_option :source_path,
    desc: "Path to local checkout of git dependencies",
    type: :string,
    default: "../"

    method_option :starting_manifest,
    desc: "Path to version-manifest from the last version (we attempt to pull it from the git history if not given)",
    type: :string

    method_option :ending_manifest,
    desc: "Path to the version-manifest from the current version",
    type: :string,
    default: "version-manifest.json"

    method_option :skip_components,
    desc: "Don't include component changes in the changelog",
    type: :boolean,
    default: false

    method_option :major,
    desc: "Bump the major version",
    type: :boolean,
    default: false

    method_option :minor,
    desc: "Bump the minor version",
    type: :boolean,
    default: true

    method_option :patch,
    desc: "Bump the patch version",
    type: :boolean,
    default: false

    method_option :version,
    desc: "Explicit version for this changelog",
    type: :string

    desc 'generate', 'Generate a changelog for a new release'
    def generate
      g = GitRepository.new

      if @options[:skip_components]
        diff = Omnibus::EmptyManifestDiff.new
      else
        old_manifest = if @options[:starting_manifest]
                         Omnibus::Manifest.from_file(@options[:starting_manifest])
                       else
                         Omnibus::Manifest.from_hash(JSON.parse(g.file_at_revision("version-manifest.json",
                                                                                   g.latest_tag)))
                       end
        new_manifest = Omnibus::Manifest.from_file(@options[:ending_manifest])
        diff = Omnibus::ManifestDiff.new(old_manifest, new_manifest)
      end

      new_version = if @options[:version]
                      @options[:version]
                    elsif @options[:patch]
                      Omnibus::SemanticVersion.new(g.latest_tag).next_patch.to_s
                    elsif @options[:minor] && !@options[:major] # minor is the default so it will always be true
                      Omnibus::SemanticVersion.new(g.latest_tag).next_minor.to_s
                    elsif @options[:major]
                      Omnibus::SemanticVersion.new(g.latest_tag).next_major.to_s
                    end


      Omnibus::ChangeLogPrinter.new(ChangeLog.new(),
                                    diff,
                                    @options[:source_path]).print(new_version)
    end
  end
end
