#
# Copyright 2015-2018 Chef Software, Inc.
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

require "omnibus/changelog"
require "omnibus/changelog_printer"
require "omnibus/manifest_diff"
require "omnibus/semantic_version"
require "ffi_yajl" unless defined?(FFI_Yajl)

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

    desc "generate [START] [END]", "Generate a changelog for a new release"
    def generate(start_ref = nil, end_ref = nil)
      @start_ref = start_ref
      @end_ref = end_ref
      diff = if @options[:skip_components]
               Omnibus::EmptyManifestDiff.new
             else
               Omnibus::ManifestDiff.new(old_manifest, new_manifest)
             end

      Omnibus::ChangeLogPrinter.new(ChangeLog.new(starting_revision, ending_revision),
        diff,
        @options[:source_path]).print(new_version)
    end

    private

    def local_git_repo
      GitRepository.new
    end

    def old_manifest
      @old_manifest ||= if @options[:starting_manifest]
                          Omnibus::Manifest.from_file(@options[:starting_manifest])
                        else
                          manifest_for_revision(starting_revision)
                        end
    end

    def new_manifest
      @new_manifest ||= if @options[:ending_manifest]
                          Omnibus::Manifest.from_file(@options[:ending_manifest])
                        else
                          manifest_for_revision(ending_revision)
                        end
    end

    def manifest_for_revision(rev)
      Omnibus::Manifest.from_hash(FFI_Yajl::Parser.parse(local_git_repo.file_at_revision("version-manifest.json", rev)))
    end

    def new_version
      if @options[:version]
        @options[:version]
      elsif @options[:patch]
        Omnibus::SemanticVersion.new(local_git_repo.latest_tag).next_patch.to_s
      elsif @options[:minor] && !@options[:major] # minor is the default so it will always be true
        Omnibus::SemanticVersion.new(local_git_repo.latest_tag).next_minor.to_s
      elsif @options[:major]
        Omnibus::SemanticVersion.new(local_git_repo.latest_tag).next_major.to_s
      elsif @options[:ending_manifest]
        new_manifest.build_version
      end
    end

    # starting_revision is taken from:
    # - value passed as the first argument
    # - value found in the starting manifest
    # - the latest git tag in the local repository
    def starting_revision
      @start_ref ||= if @options[:starting_manifest]
                       old_manifest.build_git_revision
                     else
                       local_git_repo.latest_tag
                     end
    end

    # ending_revision is taken from:
    # - value passed as the first argument
    # - value found in the ending manifest
    # - HEAD in the current git repository
    def ending_revision
      @end_ref ||= if @options[:ending_manifest]
                     new_manifest.build_git_revision
                   else
                     "HEAD"
                   end
    end
  end
end
