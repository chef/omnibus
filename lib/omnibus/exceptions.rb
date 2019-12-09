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
  class Error < RuntimeError; end

  class NoPackageFile < Error
    def initialize(path)
      @path = path
    end

    def to_s
      <<~EOH
        Could not locate or access the package at the given path:

            #{@path}
      EOH
    end
  end

  class NoPackageMetadataFile < Error
    def initialize(path)
      @path = path
    end

    def to_s
      <<~EOH
        Could not locate or access the package metadata file at the given path:

            #{@path}
      EOH
    end
  end

  class MissingRequiredAttribute < Error
    def initialize(instance, name, sample = "<VALUE>")
      @instance, @name, @sample = instance, name, sample
      @class = instance.class.name.split("::").last
    end

    def to_s
      <<~EOH
        Missing required attribute `#{@name}' for #{@class}. You must
        specify a value for `#{@name}' in your DSL file:

            #{@name} #{@sample.inspect}

        Or set the value on the object:

            #{@class.downcase}.#{@name}(#{@sample.inspect})
      EOH
    end
  end

  class MissingPatch < Error
    def initialize(name, search_paths)
      @name, @search_paths = name, search_paths
    end

    def to_s
      <<~EOH
        Attempting to apply the patch `#{@name}', but it was not found at any of the
        following locations:

        #{@search_paths.map { |path| "    #{path}" }.join("\n")}
      EOH
    end
  end

  class MissingTemplate < Error
    def initialize(template, search_paths)
      @template, @search_paths = template, search_paths
    end

    def to_s
      <<~EOH
        Attempting to evaluate the template `#{@template}', but it was not found at any of
        the following locations:

        #{@search_paths.map { |path| "    #{path}" }.join("\n")}
      EOH
    end
  end

  class MissingProject < Error
    def initialize(name)
      @name = name
      @possible_paths = Omnibus.possible_paths_for(Config.project_dir)
    end

    def to_s
      <<~EOH
        I could not find a project named `#{@name}' in any of the project locations:"

        #{@possible_paths.map { |path| "    #{path}" }.join("\n")}
      EOH
    end
  end

  class MissingSoftware < Error
    def initialize(name)
      @name = name
      @possible_paths = Omnibus.possible_paths_for(Config.software_dir)
    end

    def to_s
      <<~EOH
        I could not find a software named `#{@name}' in any of the software locations:"

        #{@possible_paths.map { |path| "    #{path}" }.join("\n")}
      EOH
    end
  end

  class GemNotInstalled < Error
    def initialize(name)
      @name = name
    end

    def to_s
      <<~EOH
        I could not load the `#{@name}' gem. Please make sure the gem is installed on
        your local system by running `gem install #{@name}`, or by adding the following
        to your Gemfile:

            gem '#{@name}'
      EOH
    end
  end

  class InsufficientSpecification < Error
    def initialize(key, package)
      @key, @package = key, package
    end

    def to_s
      <<~EOH
        Software must specify a `#{@key}; to cache it in S3 (#{@package})!
      EOH
    end
  end

  class InvalidValue < Error
    #
    # @param [Symbol] source
    #   the source method that received an invalid value
    # @param [String] message
    #   the message about why the value is invalid
    #
    def initialize(source, message)
      @source  = source
      @message = message
    end

    def to_s
      <<~EOH
        Invalid value for `#{@source}'. Expected #{@source} to #{@message}!
      EOH
    end
  end

  #
  # Raised when Omnibus encounters a platform it does not know how to
  # build/check/handle.
  #
  class UnknownPlatform < Error
    def initialize(platform)
      @platform = platform
    end

    def to_s
      <<~EOH
        Unknown platform `#{@platform}'!
        I do not know how to proceed!"
      EOH
    end
  end

  #
  # Raised when Omnibus encounters a platform_version it does not know how to
  # build/check/handle.
  #
  class UnknownPlatformVersion < Error
    def initialize(platform, version)
      @platform, @version = platform, version
    end

    def to_s
      <<~EOH
        Unknown platform version `#{@version}' for #{@platform}!
        I do not know how to proceed!"
      EOH
    end
  end

  class HealthCheckFailed < Error
    def to_s
      <<~EOH
        The health check failed! Please see above for important information.
      EOH
    end
  end

  class ChecksumMissing < Error
    def initialize(software)
      super <<~EOH
        Verification for #{software.name} failed due to a missing checksum.

        This added security check is used to prevent MITM attacks when downloading the
        remote file. You must specify a checksum for each version of software downloaded
        from a remote location.
      EOH
    end
  end

  class ChecksumMismatch < Error
    def initialize(software, expected, actual)
      super <<~EOH
        Verification for #{software.name} failed due to a checksum mismatch:

            expected: #{expected}
            actual:   #{actual}

        This added security check is used to prevent MITM attacks when downloading the
        remote file. If you have updated the version or URL for the download, you will
        also need to update the checksum value. You can find the checksum value on the
        software publisher's website.
      EOH
    end
  end

  class CommandFailed < Error
    def initialize(cmd)
      status = cmd.exitstatus

      if cmd.environment.nil? || cmd.environment.empty?
        env = nil
      else
        env = cmd.environment.sort.map { |k, v| "#{k}=#{v}" }.join(" ")
      end

      command = cmd.command
      command_with_env = [env, command].compact.join(" ")

      stdout = cmd.stdout.empty? ? "(nothing)" : cmd.stdout.strip
      stderr = cmd.stderr.empty? ? "(nothing)" : cmd.stderr.strip

      super <<~EOH
        The following shell command exited with status #{status}:

            $ #{command_with_env}

        Output:

            #{stdout}

        Error:

            #{stderr}
      EOH
    end
  end

  class CommandTimeout < Error
    def initialize(cmd)
      status = cmd.exitstatus

      if cmd.environment.nil? || cmd.environment.empty?
        env = nil
      else
        env = cmd.environment.sort.map { |k, v| "#{k}=#{v}" }.join(" ")
      end

      command = cmd.command
      command_with_env = [env, command].compact.join(" ")

      timeout = cmd.timeout.to_s.reverse.gsub(/...(?=.)/, '\&,').reverse

      super <<~EOH
        The following shell command timed out at #{timeout} seconds:

            $ #{command_with_env}

        Please increase the `:timeout' value or run the command manually to make sure it
        is completing successfully. Sometimes it is common for a command to wait for
        user input.
      EOH
    end
  end

  class ProjectAlreadyDirty < Error
    def initialize(project)
      name = project.name
      culprit = project.culprit.name

      super <<~EOH
        The project `#{name}' was already marked as dirty by `#{culprit}'. You cannot
        mark a project as dirty twice. This is probably a bug in Omnibus and should be
        reported.
      EOH
    end
  end

  class UnresolvableGitReference < Error
    def initialize(ref)
      super <<~EOH
        Could not resolve `#{ref}' to a valid git SHA-1.
      EOH
    end
  end

  class InvalidVersion < Error
    def initialize(version)
      super <<~EOF
        '#{version}' could not be parsed as a valid version.
      EOF
    end
  end

  class FailedToSignWindowsPackage < Error
    def initialize
      super("Failed to sign Windows Package.")
    end
  end

  class LicensingError < Error
    def initialize(errors)
      @errors = errors
    end

    def to_s
      <<~EOH
        Encountered error(s) with project's licensing information.
        Failing the build because :fatal_licensing_warnings is set in the configuration.
        Error(s):

            #{@errors.join("\n    ")}
      EOH
    end
  end
end
