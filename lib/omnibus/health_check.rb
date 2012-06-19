#
# Copyright:: Copyright (c) 2012 Opscode, Inc.
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

module Omnibus
  class HealthCheck

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
                              /libuutil\.so/
                             ]

    FREEBSD_WHITELIST_LIBS = [
                              /libc.so/,
                              /libcrypt.so/,
                              /libcrypto.so/,
                              /libcurses\.so/,
                              /libm\.so/,
                              /librt\.so/,
                              /libthr\.so/,
                              /libutil\.so/,
                              /libz\.so/
                             ]

    MAC_WHITELIST_LIBS = [
      /libobjc\.A\.dylib/,
      /libSystem\.B\.dylib/,
      /CoreFoundation/,
      /Tcl$/,
      /Cocoa$/,
      /Carbon$/,
      /IOKit$/,
      /Tk$/,
      /libutil\.dylib/,
      /libffi\.dylib/,
      /libncurses\.5\.4\.dylib/,
      /libiconv/
    ]
    
    WHITELIST_FILES = [
                       /jre\/bin\/javaws/,
                       /jre\/bin\/policytool/,
                       /jre\/lib/,
                       /jre\/plugin/,
                      ]

    #WHITELIST_LIBS.push(*SOLARIS_WHITELIST_LIBS)

    def self.log(msg)
      puts "[health_check] #{msg}"
    end

    def self.run(install_dir)
      if OHAI.platform == "mac_os_x"
        bad_libs = health_check_otool(install_dir)
      else
        bad_libs = health_check_ldd(install_dir)
      end

      if bad_libs.keys.length > 0
        bad_libs.each do |name, lib_hash|
          lib_hash.each do |lib, linked_libs|
            linked_libs.each do |linked, count|
              log "#{name}: #{lib} #{linked} #{count}"
            end
          end
        end
        raise "Health Check Failed"
      end
    end

    def self.health_check_otool(install_dir)
      otool_cmd = "find #{install_dir}/ -type f | egrep '\.(dylib|bundle)$' | xargs otool -L > otool.out 2>/dev/null"
      log "Executing `#{otool_cmd}`"
      shell = Mixlib::ShellOut.new(otool_cmd, :timeout => 3600)
      shell.run_command

      otool_output = File.read('otool.out')

      current_library = nil
      bad_libs = {}

      otool_output.each_line do |line|
        case line
        when /^(.+):$/
          current_library = $1
        when /^\s+(.+) \(.+\)$/
          linked = $1
          name = File.basename(linked)
          bad_libs = check_for_bad_library(install_dir, bad_libs, current_library, name, linked)
        end
      end

      File.delete('otool.out')

      bad_libs
    end

    def self.check_for_bad_library(install_dir, bad_libs, current_library, name, linked)
      safe = nil

      whitelist_libs = case OHAI.platform
                       when 'mac_os_x'
                         MAC_WHITELIST_LIBS
                       when 'freebsd'
                         FREEBSD_WHITELIST_LIBS
                       when 'solaris2'
                         SOLARIS_WHITELIST_LIBS
                       else
                         WHITELIST_LIBS
                       end
      whitelist_libs.each do |reg| 
        safe ||= true if reg.match(name)
      end
      WHITELIST_FILES.each do |reg|
        safe ||= true if reg.match(current_library)
      end

      if !safe && linked !~ Regexp.new(install_dir)
        bad_libs[current_library] ||= {}
        bad_libs[current_library][name] ||= {} 
        if bad_libs[current_library][name].has_key?(linked)
          bad_libs[current_library][name][linked] += 1 
        else
          bad_libs[current_library][name][linked] = 1 
        end
      else
        log "Passed: #{current_library} #{name} #{linked}" if ARGV[0] == 'verbose'
      end

      bad_libs
    end
    
    def self.health_check_ldd(install_dir)
      #
      # ShellOut has GC turned off during execution, so when we're
      # executing extremely long commands with lots of output, we
      # should be mindful that the string concatentation for building
      # #stdout will hurt memory usage drastically
      #
      ldd_cmd = "find #{install_dir}/ -type f | xargs ldd > ldd.out 2>/dev/null"
      log "Executing `#{ldd_cmd}`"
      shell = Mixlib::ShellOut.new(ldd_cmd, :timeout => 3600)
      shell.run_command

      ldd_output = File.read('ldd.out')

      current_library = nil
      bad_libs = {}

      ldd_output.each_line do |line|
        case line
        when /^(.+):$/
          current_library = $1
        when /^\s+(.+) \=\>\s+(.+)( \(.+\))?$/
          name = $1
          linked = $2
          bad_libs = check_for_bad_library(install_dir, bad_libs, current_library, name, linked)
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
          log "line did not match for #{current_library}\n#{line}"
        end
      end

      File.delete('ldd.out')
      bad_libs
    end

  end
end
