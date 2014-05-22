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

module Omnibus
  class Error < RuntimeError
  end

  class AbstractMethod < Error
    def initialize(signature)
      @signature = signature
    end

    def to_s
      "'#{@signature}' is an abstract method and must be overridden!"
    end
  end

  class ProjectNotFound < Error
    def initialize(name)
      @name = name
    end

    def to_s
      out = "I could not find an Omnibus project named '#{@name}'! "
      out << "Valid projects are:\n"

      Omnibus.project_names.sort.each do |project_name|
        out << "  * #{project_name}\n"
      end

      out.strip
    end
  end

  class MissingAsset < Error
    def initialize(path)
      @path = path
    end

    def to_s
      "Missing asset! '#{@path}' is not present on disk."
    end
  end

  class InvalidS3Configuration < Error
    def initialize(s3_bucket, s3_access_key, s3_secret_key)
      @s3_bucket, @s3_access_key, @s3_secret_key = s3_bucket, s3_access_key, s3_secret_key
    end

    def to_s
      <<-EOH
One or more required S3 configuration values is missing.

Your effective configuration was the following:

    s3_bucket     #{@s3_bucket.inspect}
    s3_access_key #{@s3_access_key.inspect}
    s3_secret_key #{@s3_secret_key.inspect}

If you truly do want S3 caching, you should add values similar to the following
in your Omnibus config file:

    s3_bucket     ENV['S3_BUCKET_NAME']
    s3_access_key ENV['S3_ACCESS_KEY']
    s3_secret_key ENV['S3_SECRET_KEY']

Note that you are not required to use environment variables as illustrated (and
the ones listed have no special significance in Omnibus), but it is encouraged
to prevent spread of sensitive information and inadvertent check-in of same to
version control systems.
      EOH
    end
  end

  class BadReplacesLine < Error
    def to_s
      <<-EOH
The `replaces` project DSL statement should never equal the `package_name` or
`name` of a project. The `replaces` option should only be used when you have
published an artifact under one name and then later renamed the packages that
you are publishing and you must obsolete the old package name. For example this
is used, correctly, in chef-client builds:

    name 'chef'
    replaces 'chef-full'

The RPMs and debs which were originally published were named "chef-full" and
this was later renamed, and in order to upgrade the (very old) "chef-full"
packages the new "chef" packages needed to know to uninstall any "chef-full"
packages that were found. Projects which have never been renamed, however,
should never use the replaces line.
      EOH
    end
  end

  class NoPackageFile < Error
    def initialize(package_path)
      @package_path = package_path
    end

    def to_s
      """
      Cannot locate or access the package at the given path:

        #{@package_path}
      """
    end
  end

  class NoPackageMetadataFile < Error
    def initialize(package_metadata_path)
      @package_metadata_path = package_metadata_path
    end

    def to_s
      """
      Cannot locate or access the package metadata file at the given path:

        #{@package_metadata_path}
      """
    end
  end

  class InvalidS3ReleaseConfiguration < Error
    def to_s
      """
      One or more required S3 configuration values is missing.

      Your effective configuration was the following:

          release_s3_bucket     => #{Config.release_s3_bucket.inspect}
          release_s3_access_key => #{Config.release_s3_access_key.inspect}
          release_s3_secret_key => #{Config.release_s3_secret_key.inspect}

      To release a package to S3, add the following values to your
      config file:

          release_s3_bucket      ENV['S3_BUCKET_NAME']
          release_s3_access_key  ENV['S3_ACCESS_KEY']
          release_s3_secret_key  ENV['S3_SECRET_KEY']

      Note that you are not required to use environment variables as
      illustrated (and the ones listed have no special significance in
      Omnibus), but it is encouraged to prevent spread of sensitive
      information and inadvertent check-in of same to version control
      systems.

      """
    end
  end

  # Raise this error if a needed Project configuration value has not
  # been set.
  class MissingProjectConfiguration < Error
    def initialize(parameter_name, sample_value)
      @parameter_name, @sample_value = parameter_name, sample_value
    end

    def to_s
      """
      You are attempting to build a project, but have not specified
      a value for '#{@parameter_name}'!

      Please add code similar to the following to your project DSL file:

         #{@parameter_name} '#{@sample_value}'

      """
    end
  end

  # Raise this error if a needed Software configuration value has not
  # been set.
  class MissingSoftwareConfiguration < Error
    def initialize(software_name, parameter_name, sample_value)
      @software_name, @parameter_name, @sample_value = software_name, parameter_name, sample_value
    end

    def to_s
      """
      You are attempting to build software #{@sofware_name}, but have not specified
      a value for '#{@parameter_name}'!

      Please add code similar to the following to your software DSL file:

         #{@parameter_name} '#{@sample_value}'

      """
    end
  end

  class MissingPatch < Error
    def initialize(patch_name, search_paths)
      @patch_name, @search_paths = patch_name, search_paths
    end

    def to_s
      """
      Attempting to apply the patch #{@patch_name}, but it was not
      found at any of the following locations:

      #{@search_paths.join("\n      ")}
      """
    end
  end

  class MissingTemplate < Error
    def initialize(template_name, search_paths)
      @template_name, @search_paths = template_name, search_paths
    end

    def to_s
      """
      Attempting to evaluate the template #{@template_name}, but it was not
      found at any of the following locations:

      #{@search_paths.join("\n      ")}
      """
    end
  end

  class MissingProjectDependency < Error
    def initialize(dep_name, search_paths)
      @dep_name, @search_paths = dep_name, search_paths
    end

    def to_s
      """
      Attempting to load the project dependency '#{@dep_name}', but it was
      not found at any of the following locations:

      #{@search_paths.join("\n      ")}
      """
    end
  end

  class UnresolvableGitReference < Error
  end

  class UnknownPublisher < Error
    def initialize(backend)
      @backend  = backend
      @backends = Omnibus.constants
                    .map(&:to_s)
                    .select { |const| const.to_s =~ /^(.+)Publisher$/ }
                    .sort
    end

    def to_s
      <<-EOH
I could not find a publisher named #{@backend}. Valid publishers are:

    #{@backends.join("\n    ")}

Please make sure you have spelled everything correctly and try again. If this
error persists, please open an issue on GitHub.
      EOH
    end
  end

  class GemNotInstalled < Error
    def initialize(name)
      @name = name
    end

    def to_s
      <<-EOH
        I could not load the '#{@name}' gem. Please make sure the gem is
        installed on your local system by running `gem install #{@name}`,
        or by adding the following to your Gemfile:

            gem '#{@name}'

      EOH
    end
  end
end
