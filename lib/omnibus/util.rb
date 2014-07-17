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

require 'mixlib/shellout'

module Omnibus
  module Util
    #
    # The default shellout options.
    #
    # @return [Hash]
    #
    SHELLOUT_OPTIONS = {
      live_stream: Omnibus.logger.live_stream(:debug),
      timeout: 7200, # 2 hours
      environment: {},
    }.freeze

    #
    # Shells out and runs +command+.
    #
    # @overload shellout(command, options = {})
    #   @param command [String]
    #   @param options [Hash] the options passed to the initializer of the
    #     +Mixlib::ShellOut+ instance.
    # @overload shellout(command_fragments, options = {})
    #   @param command [Array<String>] command argv as individual strings
    #   @param options [Hash] the options passed to the initializer of the
    #     +Mixlib::ShellOut+ instance.
    # @return [Mixlib::ShellOut] the underlying +Mixlib::ShellOut+ instance
    #   which which has +stdout+, +stderr+, +status+, and +exitstatus+
    #   populated with results of the command.
    #
    def shellout(*args)
      options = args.last.kind_of?(Hash) ? args.pop : {}
      options = SHELLOUT_OPTIONS.merge(options)

      # Since Mixlib::ShellOut supports :environment and :env, we want to
      # standardize here
      if options[:env]
        options[:environment] = options.fetch(:environment, {}).merge(options[:env])
      end

      # Log any environment options given
      unless options[:environment].empty?
        Omnibus.logger.info { 'Environment:' }
        options[:environment].each do |key, value|
          Omnibus.logger.info { "  #{key.to_s.upcase}=#{value.inspect}" }
        end
      end

      # Log the actual command
      Omnibus.logger.info { "$ #{args.join(' ')}" }

      cmd = Mixlib::ShellOut.new(*args, options)
      cmd.environment['HOME'] = '/tmp' unless ENV['HOME']
      cmd.run_command
      cmd
    end

    # Similar to +shellout+ method except it raises an exception if the
    # command fails.
    #
    # @see #shellout
    #
    # @raise [Mixlib::ShellOut::ShellCommandFailed] if +exitstatus+ is not in
    #   the list of +valid_exit_codes+.
    #
    def shellout!(*args)
      cmd = shellout(*args)
      cmd.error!
      cmd
    end

    # Return true if the given value appears to be "truthy".
    #
    # @param [#to_s] value
    def truthy?(value)
      value && value.to_s =~ /^(true|t|yes|y|1)$/i
    end

    # Return true if the given value appears to be "falsey".
    #
    # @param [#to_s] value
    def falsey?(value)
      value && value.to_s =~ /^(false|f|no|n|0)$/i
    end

    #
    # Convert the given path to be appropiate for shelling out on Windows.
    #
    # @param [Array<String>] pieces
    #   the pieces of the path to join and fix
    # @return [String]
    #   the path with applied changes
    #
    def windows_safe_path(*pieces)
      path = File.join(*pieces)

      if File::ALT_SEPARATOR
        path.gsub(File::SEPARATOR, File::ALT_SEPARATOR)
      else
        path
      end
    end

    #
    # On certain platforms we don't care about the full MAJOR.MINOR.PATCH platform
    # version. This method will properly truncate the version down to a more human
    # friendly version. This version can also be thought of as a 'marketing'
    # version.
    #
    # @param [String] platform_version
    #   the platform version to truncate
    # @param [String] platform_shortname
    #   the platform shortname. this might be an Ohai-returned platform or
    #   platform family but it also might be a shortname like `el`
    #
    def truncate_platform_version(platform_version, platform_shortname=nil)

      case platform_shortname
      when 'centos', 'debian', 'fedora', 'freebsd', 'rhel', 'el'
        # Only want MAJOR (e.g. Debian 7)
        platform_version.split('.').first
      when 'aix', 'arch', 'gentoo', 'mac_os_x', 'openbsd', 'slackware', 'solaris2', 'suse', 'ubuntu'
        # Only want MAJOR.MINOR (e.g. Mac OS X 10.9, Ubuntu 12.04)
        platform_version.split('.')[0..1].join('.')
      when 'omnios', 'smartos'
        # Only want MAJOR (e.g OmniOS r151006, SmartOS 20120809T221258Z)
        platform_version.split('.').first
      when 'windows'
        # Windows has this really awesome "feature", where their version numbers
        # internally do not match the "marketing" name.
        #
        # Definitively computing the Windows marketing name actually takes more
        # than the platform version. Take a look at the following file for the
        # details:
        #
        #   https://github.com/opscode/chef/blob/master/lib/chef/win32/version.rb
        #
        # As we don't need to be exact here the simple mapping below is based on:
        #
        #  http://www.jrsoftware.org/ishelp/index.php?topic=winvernotes
        #
        case platform_version
        when '5.0.2195', '2000'   then '2000'
        when '5.1.2600', 'xp'     then 'xp'
        when '5.2.3790', '2003r2' then '2003r2'
        when '6.0.6001', '2008'   then '2008'
        when '6.1.7600', '7'      then '7'
        when '6.1.7601', '2008r2' then '2008r2'
        when '6.2.9200', '8'      then '8'
        # The following `when` will never match since Windows 2012's platform
        # version is the same as Windows 8. It's only here for completeness and
        # documentation.
        when '6.2.9200', '2012'   then '2012'
        when '6.3.9200', '8.1'    then '8.1'
        # The following `when` will never match since Windows 2012R2's platform
        # version is the same as Windows 8.1. It's only here for completeness
        # and documentation.
        when '6.3.9200', '2012r2' then '2012r2'
        else
          raise UnknownPlatformVersion.new(platform_shortname, platform_version)
        end
      else
        raise UnknownPlatform.new(platform_shortname)
      end
    end
  end
end
