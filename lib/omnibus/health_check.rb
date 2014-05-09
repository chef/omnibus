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
    ]

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
    ]

    AIX_WHITELIST_LIBS = [
      /libpthread\.a/,
      /libpthreads\.a/,
      /libdl.a/,
      /librtl\.a/,
      /libc\.a/,
      /libcrypt\.a/,
      /unix$/,
    ]

    SOLARIS_WHITELIST_LIBS = [
      /libaio\.so/,
      /libavl\.so/,
      /libcrypt_[di]\.so/,
      /libcrypto.so/,
      /libcurses\.so/,
      /libdoor\.so/,
      /libgcc_s\.so\.1/,
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
      /libz.so/,
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
    ]

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
    ]

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
    ]

    FREEBSD_WHITELIST_LIBS = [
      /libc\.so/,
      /libcrypt\.so/,
      /libm\.so/,
      /librt\.so/,
      /libthr\.so/,
      /libutil\.so/,
    ]

    def self.run(install_dir, whitelist_files = [])
      case Ohai.platform
      when 'mac_os_x'
        bad_libs = health_check_otool(install_dir, whitelist_files)
      when 'aix'
        bad_libs = health_check_aix(install_dir, whitelist_files)
      else
        bad_libs = health_check_ldd(install_dir, whitelist_files)
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

        log.warn { 'Health Check Failed, Summary follows:' }
        bad_omnibus_libs, bad_omnibus_bins = bad_libs.keys.partition { |k| k.include? 'embedded/lib' }

        log.warn { 'The following Omnibus-built libraries have unsafe or unmet dependencies:' }
        bad_omnibus_libs.each do |lib|
          log.warn { "    --> #{lib}" }
        end

        log.warn { 'The following Omnibus-built binaries have unsafe or unmet dependencies:' }
        bad_omnibus_bins.each do |bin|
          log.warn { "    --> #{bin}" }
        end

        if unresolved.length > 0
          log.warn { 'The following requirements could not be resolved:' }
          unresolved.each do |lib|
            log.warn { "    --> #{lib}" }
          end
        end

        if unreliable.length > 0
          log.warn { 'The following libraries cannot be guaranteed to be on target systems:' }
          unreliable.each do |lib|
            log.warn { "    --> #{lib}"  }
          end
        end

        log.warn { 'The precise failures were:' }
        detail.each do |line|
          item, dependency, location, count = line.split('|')
          reason = location =~ /not found/ ? 'Unresolved dependency' : 'Unsafe dependency'
          log.warn { "    --> #{item}" }
          log.warn { "    DEPENDS ON: #{dependency}" }
          log.warn { "      COUNT: #{count}" }
          log.warn { "      PROVIDED BY: #{location}" }
          log.warn { "      FAILED BECAUSE: #{reason}" }
        end

        raise 'Health Check Failed'
      end
    end

    def self.health_check_otool(install_dir, whitelist_files)
      otool_cmd = "find #{install_dir}/ -type f | egrep '\.(dylib|bundle)$' | xargs otool -L > otool.out 2>/dev/null"
      log.info { "Executing `#{otool_cmd}`" }
      shell = Mixlib::ShellOut.new(otool_cmd, timeout: 3600)
      shell.run_command

      otool_output = File.read('otool.out')

      current_library = nil
      bad_libs = {}

      otool_output.each_line do |line|
        case line
        when /^(.+):$/
          current_library = Regexp.last_match[1]
        when /^\s+(.+) \(.+\)$/
          linked = Regexp.last_match[1]
          name = File.basename(linked)
          bad_libs = check_for_bad_library(install_dir, bad_libs, whitelist_files, current_library, name, linked)
        end
      end

      File.delete('otool.out')

      bad_libs
    end

    def self.check_for_bad_library(install_dir, bad_libs, whitelist_files, current_library, name, linked)
      safe = nil

      whitelist_libs = case Ohai.platform
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

      log.debug { "  --> Dependency: #{name}" }
      log.debug { "  --> Provided by: #{linked}" }

      if !safe && linked !~ Regexp.new(install_dir)
        log.debug { "    -> FAILED: #{current_library} has unsafe dependencies" }
        bad_libs[current_library] ||= {}
        bad_libs[current_library][name] ||= {}
        if bad_libs[current_library][name].key?(linked)
          bad_libs[current_library][name][linked] += 1
        else
          bad_libs[current_library][name][linked] = 1
        end
      else
        log.debug { "    -> PASSED: #{name} is either whitelisted or safely provided." }
      end

      bad_libs
    end

    def self.health_check_aix(install_dir, whitelist_files)
      #
      # ShellOut has GC turned off during execution, so when we're
      # executing extremely long commands with lots of output, we
      # should be mindful that the string concatentation for building
      # #stdout will hurt memory usage drastically
      #
      ldd_cmd = "find #{install_dir}/ -type f | xargs file | grep \"RISC System\" | awk -F: '{print $1}' | xargs -n 1 ldd > ldd.out 2>/dev/null"

      log.info { "Executing `#{ldd_cmd}`" }
      shell = Mixlib::ShellOut.new(ldd_cmd, timeout: 3600)
      shell.run_command

      ldd_output = File.read('ldd.out')

      current_library = nil
      bad_libs = {}

      ldd_output.each_line do |line|
        case line
        when /^(.+) needs:$/
          current_library = Regexp.last_match[1]
          log.debug { "Analyzing dependencies for #{current_library}" }
        when /^\s+(.+)$/
          name = Regexp.last_match[1]
          linked = Regexp.last_match[1]
          bad_libs = check_for_bad_library(install_dir, bad_libs, whitelist_files, current_library, name, linked)
        when /File is not an executable XCOFF file/ # ignore non-executable files
        else
          log.warn { "Line did not match for #{current_library}\n#{line}" }
        end
      end

      File.delete('ldd.out')
      bad_libs
    end

    def self.health_check_ldd(install_dir, whitelist_files)
      #
      # ShellOut has GC turned off during execution, so when we're
      # executing extremely long commands with lots of output, we
      # should be mindful that the string concatentation for building
      # #stdout will hurt memory usage drastically
      #
      ldd_cmd = "find #{install_dir}/ -type f | xargs ldd > ldd.out 2>/dev/null"

      log.info { "Executing `#{ldd_cmd}`" }
      shell = Mixlib::ShellOut.new(ldd_cmd, timeout: 3600)
      shell.run_command

      ldd_output = File.read('ldd.out')

      current_library = nil
      bad_libs = {}

      ldd_output.each_line do |line|
        case line
        when /^(.+):$/
          current_library = Regexp.last_match[1]
          log.debug { "Analyzing dependencies for #{current_library}" }
        when /^\s+(.+) \=\>\s+(.+)( \(.+\))?$/
          name = Regexp.last_match[1]
          linked = Regexp.last_match[2]
          bad_libs = check_for_bad_library(install_dir, bad_libs, whitelist_files, current_library, name, linked)
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
          log.warn { "Line did not match for #{current_library}\n#{line}" }
        end
      end

      File.delete('ldd.out')
      bad_libs
    end
  end
end
