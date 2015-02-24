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

module Omnibus
  class HealthCheck
    include Logging
    include Util

    WHITELIST_LIBS = [
      /ld-linux/,
      /libc\.so/,
      /libcrypt\.so/,
      /libdl/,
      /libfreebl\d\.so/,
      /libgcc_s\.so/,
      /libm\.so/,
      /libnsl\.so/,
      /libpthread/,
      /libresolv\.so/,
      /librt\.so/,
      /libstdc\+\+\.so/,
      /libutil\.so/,
      /linux-vdso.+/,
      /linux-gate\.so/,
    ].freeze

    ARCH_WHITELIST_LIBS = [
      /libc\.so/,
      /libcrypt\.so/,
      /libdb-5\.3\.so/,
      /libdl\.so/,
      /libffi\.so/,
      /libgdbm\.so/,
      /libm\.so/,
      /libnsl\.so/,
      /libpthread\.so/,
      /librt\.so/,
      /libutil\.so/,
    ].freeze

    AIX_WHITELIST_LIBS = [
      /libpthread\.a/,
      /libpthreads\.a/,
      /libdl.a/,
      /librtl\.a/,
      /libc\.a/,
      /libcrypt\.a/,
      /unix$/,
    ].freeze

    SOLARIS_WHITELIST_LIBS = [
      /libaio\.so/,
      /libavl\.so/,
      /libcrypt_[di]\.so/,
      /libcrypto.so/,
      /libcurses\.so/,
      /libdoor\.so/,
      /libgen\.so/,
      /libmd5\.so/,
      /libmd\.so/,
      /libmp\.so/,
      /libscf\.so/,
      /libsec\.so/,
      /libsocket\.so/,
      /libssl.so/,
      /libthread.so/,
      /libuutil\.so/,
      # solaris 11 libraries:
      /libc\.so\.1/,
      /libm\.so\.2/,
      /libdl\.so\.1/,
      /libnsl\.so\.1/,
      /libpthread\.so\.1/,
      /librt\.so\.1/,
      /libcrypt\.so\.1/,
      /libgdbm\.so\.3/,
      # solaris 9 libraries:
      /libm\.so\.1/,
      /libc_psr\.so\.1/,
      /s9_preload\.so\.1/,
    ].freeze

    SMARTOS_WHITELIST_LIBS = [
      /libm.so/,
      /libpthread.so/,
      /librt.so/,
      /libsocket.so/,
      /libdl.so/,
      /libnsl.so/,
      /libgen.so/,
      /libmp.so/,
      /libmd.so/,
      /libc.so/,
      /libgcc_s.so/,
      /libstdc\+\+\.so/,
      /libcrypt.so/,
    ].freeze

    MAC_WHITELIST_LIBS = [
      /libobjc\.A\.dylib/,
      /libSystem\.B\.dylib/,
      /CoreFoundation/,
      /CoreServices/,
      /Tcl$/,
      /Cocoa$/,
      /Carbon$/,
      /IOKit$/,
      /Tk$/,
      /libutil\.dylib/,
      /libffi\.dylib/,
      /libncurses\.5\.4\.dylib/,
      /libiconv/,
      /libstdc\+\+\.6\.dylib/,
      /libc\+\+\.1\.dylib/,
    ].freeze

    FREEBSD_WHITELIST_LIBS = [
      /libc\.so/,
      /libgcc_s\.so/,
      /libcrypt\.so/,
      /libm\.so/,
      /librt\.so/,
      /libthr\.so/,
      /libutil\.so/,
      /libelf\.so/,
    ].freeze

    class << self
      # @see (HealthCheck#new)
      def run!(project)
        new(project).run!
      end
    end

    #
    # The project to healthcheck.
    #
    # @return [Project]
    #
    attr_reader :project

    #
    # Run the healthchecks against the given project. It is assumed that the
    # project has already been built.
    #
    # @param [Project] project
    #   the project to health check
    #
    def initialize(project)
      @project = project
    end

    #
    # Run the given health check. Healthcheks are skipped on Windows.
    #
    # @raise [HealthCheckFailed]
    #   if the health check fails
    #
    # @return [true]
    #   if the healthchecks pass
    #
    def run!
      if Ohai['platform'] == 'windows'
        log.warn(log_key) { 'Skipping health check on Windows' }
        return true
      end
      log.info(log_key) {"Running health on #{project.name}"}
      bad_libs =  case Ohai['platform']
                  when 'mac_os_x'
                    health_check_otool
                  when 'aix'
                    health_check_aix
                  else
                    health_check_ldd
                  end

      unresolved = []
      unreliable = []
      detail = []

      if bad_libs.keys.length > 0
        bad_libs.each do |name, lib_hash|
          lib_hash.each do |lib, linked_libs|
            linked_libs.each do |linked, count|
              if linked =~ /not found/
                unresolved << lib unless unresolved.include? lib
              else
                unreliable << linked unless unreliable.include? linked
              end
              detail << "#{name}|#{lib}|#{linked}|#{count}"
            end
          end
        end

        log.error(log_key) { 'Failed!' }
        bad_omnibus_libs, bad_omnibus_bins = bad_libs.keys.partition { |k| k.include? 'embedded/lib' }

        log.error(log_key) do
          out = "The following libraries have unsafe or unmet dependencies:\n"

          bad_omnibus_libs.each do |lib|
            out << "    --> #{lib}\n"
          end

          out
        end

        log.error(log_key) do
          out = "The following binaries have unsafe or unmet dependencies:\n"

          bad_omnibus_bins.each do |bin|
            out << "    --> #{bin}\n"
          end

          out
        end

        if unresolved.length > 0
          log.error(log_key) do
            out = "The following requirements could not be resolved:\n"

            unresolved.each do |lib|
              out << "    --> #{lib}\n"
            end

            out
          end
        end

        if unreliable.length > 0
          log.error(log_key) do
            out =  "The following libraries cannot be guaranteed to be on "
            out << "target systems:\n"

            unreliable.each do |lib|
              out << "    --> #{lib}\n"
            end

            out
          end
        end

        log.error(log_key) do
          out = "The precise failures were:\n"

          detail.each do |line|
            item, dependency, location, count = line.split('|')
            reason = location =~ /not found/ ? 'Unresolved dependency' : 'Unsafe dependency'

            out << "    --> #{item}\n"
            out << "    DEPENDS ON: #{dependency}\n"
            out << "      COUNT: #{count}\n"
            out << "      PROVIDED BY: #{location}\n"
            out << "      FAILED BECAUSE: #{reason}\n"
          end

          out
        end

        raise HealthCheckFailed
      end

      true
    end

    #
    # Run healthchecks against otool.
    #
    # @return [Array<String>]
    #   the bad libraries
    #
    def health_check_otool
      current_library = nil
      bad_libs = {}

      read_shared_libs("find #{project.install_dir}/ -type f | egrep '\.(dylib|bundle)$' | xargs otool -L") do |line|
        case line
        when /^(.+):$/
          current_library = Regexp.last_match[1]
        when /^\s+(.+) \(.+\)$/
          linked = Regexp.last_match[1]
          name = File.basename(linked)
          bad_libs = check_for_bad_library(bad_libs, current_library, name, linked)
        end
      end

      bad_libs
    end

    #
    # Run healthchecks against aix.
    #
    # @return [Array<String>]
    #   the bad libraries
    #
    def health_check_aix
      current_library = nil
      bad_libs = {}

      read_shared_libs("find #{project.install_dir}/ -type f | xargs file | grep \"RISC System\" | awk -F: '{print $1}' | xargs -n 1 ldd") do |line|
        case line
        when /^(.+) needs:$/
          current_library = Regexp.last_match[1]
          log.debug(log_key) { "Analyzing dependencies for #{current_library}" }
        when /^\s+(.+)$/
          name = Regexp.last_match[1]
          linked = Regexp.last_match[1]
          bad_libs = check_for_bad_library(bad_libs, current_library, name, linked)
        when /File is not an executable XCOFF file/ # ignore non-executable files
        else
          log.warn(log_key) { "Line did not match for #{current_library}\n#{line}" }
        end
      end

      bad_libs
    end

    #
    # Run healthchecks against ldd.
    #
    # @return [Array<String>]
    #   the bad libraries
    #
    def health_check_ldd
      current_library = nil
      bad_libs = {}

      read_shared_libs("find #{project.install_dir}/ -type f | xargs ldd") do |line|
        case line
        when /^(.+):$/
          current_library = Regexp.last_match[1]
          log.debug(log_key) { "Analyzing dependencies for #{current_library}" }
        when /^\s+(.+) \=\>\s+(.+)( \(.+\))?$/
          name = Regexp.last_match[1]
          linked = Regexp.last_match[2]
          bad_libs = check_for_bad_library(bad_libs, current_library, name, linked)
        when /^\s+(.+) \(.+\)$/
          next
        when /^\s+statically linked$/
          next
        when /^\s+libjvm.so/
          next
        when /^\s+libjava.so/
          next
        when /^\s+libmawt.so/
          next
        when /^\s+not a dynamic executable$/ # ignore non-executable files
        else
          log.warn(log_key) do
            "Line did not match for #{current_library}\n#{line}"
          end
        end
      end

      bad_libs
    end

    private

    #
    # The list of whitelisted (ignored) files from the project and softwares.
    #
    # @return [Array<String, Regexp>]
    #
    def whitelist_files
      project.library.components.inject([]) do |array, component|
        array += component.whitelist_files
        array
      end
    end

    #
    # Execute the given command, yielding each line.
    #
    # @param [String] command
    #   the command to execute
    # @yield [String]
    #   each line
    #
    def read_shared_libs(command)
      cmd = shellout(command)
      cmd.stdout.each_line do |line|
        yield line
      end
    end

    #
    # Check the given path and library for "bad" libraries.
    #
    def check_for_bad_library(bad_libs, current_library, name, linked)
      safe = nil

      whitelist_libs = case Ohai['platform']
                       when 'arch'
                         ARCH_WHITELIST_LIBS
                       when 'mac_os_x'
                         MAC_WHITELIST_LIBS
                       when 'solaris2'
                         SOLARIS_WHITELIST_LIBS
                       when 'smartos'
                         SMARTOS_WHITELIST_LIBS
                       when 'freebsd'
                         FREEBSD_WHITELIST_LIBS
                       when 'aix'
                         AIX_WHITELIST_LIBS
                       else
                         WHITELIST_LIBS
                       end

      whitelist_libs.each do |reg|
        safe ||= true if reg.match(name)
      end

      whitelist_files.each do |reg|
        safe ||= true if reg.match(current_library)
      end

      log.debug(log_key) { "  --> Dependency: #{name}" }
      log.debug(log_key) { "  --> Provided by: #{linked}" }

      if !safe && linked !~ Regexp.new(project.install_dir)
        log.debug(log_key) { "    -> FAILED: #{current_library} has unsafe dependencies" }
        bad_libs[current_library] ||= {}
        bad_libs[current_library][name] ||= {}
        if bad_libs[current_library][name].key?(linked)
          bad_libs[current_library][name][linked] += 1
        else
          bad_libs[current_library][name][linked] = 1
        end
      else
        log.debug(log_key) { "    -> PASSED: #{name} is either whitelisted or safely provided." }
      end

      bad_libs
    end
  end
end
