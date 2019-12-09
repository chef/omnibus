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

require "omnibus/sugarable"
begin
  require "pedump"
rescue LoadError
  STDERR.puts "pedump not found - windows health checks disabled"
end

module Omnibus
  class HealthCheck
    include Instrumentation
    include Logging
    include Util
    include Sugarable

    WHITELIST_LIBS = [
      /ld-linux/,
      /libc\.so/,
      /libcrypt\.so/,
      /libdb-4.7\.so/,
      /libdb-5.3\.so/,
      /libdl/,
      /libfreebl\d\.so/,
      /libgcc_s\.so/,
      /libm\.so/,
      /libnsl\.so/,
      /libpthread/,
      /libresolv\.so/,
      /librt\.so/,
      /librrd\.so/,
      /libstdc\+\+\.so/,
      /libutil\.so/,
      /linux-vdso.+/,
      /linux-gate\.so/,
      /rrdtoolmodule\.so/,
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
      /libresolv\.so/,
      /libscf\.so/,
      /libsec\.so/,
      /libsocket\.so/,
      /libssl.so/,
      /libthread.so/,
      /libuutil\.so/,
      /libkstat\.so/,
      # solaris 11 libraries:
      /libc\.so\.1/,
      /libm\.so\.2/,
      /libdl\.so\.1/,
      /libnsl\.so\.1/,
      /libpthread\.so\.1/,
      /librt\.so\.1/,
      /libcrypt\.so\.1/,
      /libgdbm\.so\.3/,
      /libgcc_s\.so\.1/,
      /libcryptoutil\.so\.1/,
      /libucrypto\.so\.1/,
      /libz\.so\.1/, # while we package our own libz, this get dragged along from Solaris 11's libelf library for some reason...
      /libelf\.so\.1/,
      /libssp\.so\.0/,
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
      # Symlink of the previous one
      /libgcc_s\.1\.dylib/,
      /CoreFoundation/,
      /CoreServices/,
      /Tcl$/,
      /Cocoa$/,
      /Carbon$/,
      /IOKit$/,
      /Kerberos/,
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
      /libkvm\.so/,
      /libprocstat\.so/,
      /libmd\.so/,
    ].freeze

    IGNORED_ENDINGS = %w{
      .[ch]
      .e*rb
      .gemspec
      .gitignore
      .h*h
      .java
      .js
      .json
      .lock
      .log
      .lua
      .md
      .mkd
      .out
      .pl
      .pm
      .png
      .py[oc]*
      .r*html
      .rdoc
      .ri
      .sh
      .sql
      .toml
      .ttf
      .txt
      .xml
      .yml
      Gemfile
      LICENSE
      README
      Rakefile
      VERSION
    }.freeze

    IGNORED_PATTERNS = %w{
      /share/doc/
      /share/postgresql/
      /share/terminfo/
      /terminfo/
    }.freeze

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
      measure("Health check time") do
        log.info(log_key) { "Running health on #{project.name}" }
        bad_libs =  case Ohai["platform"]
                    when "mac_os_x"
                      health_check_otool
                    when "aix"
                      health_check_aix
                    when "windows"
                      # TODO: objdump -p will provided a very limited check of
                      # explicit dependencies on windows. Most dependencies are
                      # implicit and hence not detected.
                      log.warn(log_key) { "Skipping dependency health checks on Windows." }
                      {}
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

          log.error(log_key) { "Failed!" }
          bad_omnibus_libs, bad_omnibus_bins = bad_libs.keys.partition { |k| k.include? "embedded/lib" }

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
              item, dependency, location, count = line.split("|")
              reason = location =~ /not found/ ? "Unresolved dependency" : "Unsafe dependency"

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

        conflict_map = {}

        conflict_map = relocation_check if relocation_checkable?

        if conflict_map.keys.length > 0
          log.warn(log_key) { "Multiple dlls with overlapping images detected" }

          conflict_map.each do |lib_name, data|
            base = data[:base]
            size = data[:size]
            next_valid_base = data[:base] + data[:size]

            log.warn(log_key) do
              out =  "Overlapping dll detected:\n"
              out << "    #{lib_name} :\n"
              out << "    IMAGE BASE: #{hex}\n" % base
              out << "    IMAGE SIZE: #{hex} (#{size} bytes)\n" % size
              out << "    NEXT VALID BASE: #{hex}\n" % next_valid_base
              out << "    CONFLICTS:\n"

              data[:conflicts].each do |conflict_name|
                cbase = conflict_map[conflict_name][:base]
                csize = conflict_map[conflict_name][:size]
                out << "    - #{conflict_name} #{hex} + #{hex}\n" % [cbase, csize]
              end

              out
            end
          end

          # Don't raise an error yet. This is only bad for FIPS mode.
        end

        true
      end
    end

    # Ensure the method relocation_check is able to run
    #
    # @return [Boolean]
    #
    def relocation_checkable?
      return false unless windows?

      begin
        require "pedump"
        true
      rescue LoadError
        false
      end
    end

    # Check dll image location overlap/conflicts on windows.
    #
    # @return [Hash<String, Hash<Symbol, ...>>]
    #   library_name ->
    #     :base -> base address
    #     :size -> the total image size in bytes
    #     :conflicts -> array of library names that overlap
    #
    def relocation_check
      conflict_map = {}

      embedded_bin = "#{project.install_dir}/embedded/bin"
      Dir.glob("#{embedded_bin}/*.dll") do |lib_path|
        log.debug(log_key) { "Analyzing dependencies for #{lib_path}" }

        File.open(lib_path, "rb") do |f|
          dump = PEdump.new(lib_path)
          pe = dump.pe f

          # Don't scan dlls for a different architecture.
          next if windows_arch_i386? == pe.x64?

          lib_name = File.basename(lib_path)
          base = pe.ioh.ImageBase
          size = pe.ioh.SizeOfImage
          conflicts = []

          # This can be done more smartly but O(n^2) is just fine for n = small
          conflict_map.each do |candidate_name, details|
            unless details[:base] >= base + size ||
                   details[:base] + details[:size] <= base
              details[:conflicts] << lib_name
              conflicts << candidate_name
            end
          end

          conflict_map[lib_name] = {
            base: base,
            size: size,
            conflicts: conflicts,
          }

          log.debug(log_key) { "Discovered #{lib_name} at #{hex} + #{hex}" % [base, size] }
        end
      end

      # Filter out non-conflicting entries.
      conflict_map.delete_if do |lib_name, details|
        details[:conflicts].empty?
      end
    end

    #
    # Run healthchecks against otool.
    #
    # @return [Hash<String, Hash<String, Hash<String, Int>>>]
    #   the bad libraries (library_name -> dependency_name -> satisfied_lib_path -> count)
    #
    def health_check_otool
      current_library = nil
      bad_libs = {}

      yield_shellout_results("find #{project.install_dir}/ -type f | egrep '\.(dylib|bundle)$' | xargs otool -L") do |line|
        case line
        when /^(.+):$/
          current_library = Regexp.last_match[1]
        when /^\s+(.+) \(.+\)$/
          linked = Regexp.last_match[1]
          name = File.basename(linked)
          bad_libs = check_for_bad_macos_library(bad_libs, current_library, name, linked)
        end
      end

      bad_libs
    end

    #
    # Check the given path and library for "bad" libraries.
    #
    def check_for_bad_macos_library(bad_libs, current_library, name, linked)
      safe = nil

      whitelist_libs = MAC_WHITELIST_LIBS

      whitelist_libs.each do |reg|
        safe ||= true if reg.match(name)
      end

      whitelist_files.each do |reg|
        safe ||= true if reg.match(current_library)
      end

      log.debug(log_key) { "  --> Dependency: #{name}" }
      log.debug(log_key) { "  --> Provided by: #{linked}" }

      linked_present = false

      if !safe
        rpath_regexp = Regexp.new("@rpath")
        loader_path_regexp = Regexp.new("@loader_path")
        install_dir_regexp = Regexp.new(project.install_dir)

        # Do the linker's work of replacing @rpath with the rpaths defined by the library
        if linked =~ rpath_regexp
          possible_paths = []
          # Find what are the library's rpaths by looking at the load commands.
          # Example otool -l partial output:
          # Load command 13
          #          cmd LC_LOAD_DYLIB
          #      cmdsize 56
          #         name /usr/lib/libSystem.B.dylib (offset 24)
          #   time stamp 2 Thu Jan  1 01:00:02 1970
          #      current version 1238.60.2
          # compatibility version 1.0.0
          # Load command 14
          #          cmd LC_RPATH
          #      cmdsize 48
          #         name /opt/datadog-agent/embedded/lib (offset 12)
          yield_shellout_results("otool -l #{current_library} | grep LC_RPATH -A2 | grep path | awk '{ print $2 }'") do |rpath|
            # The rpath variable contains a \n (\r\n on Windows), so we remove it when including it in the complete path
            possible_paths << linked.sub("@rpath", rpath.chop)
          end
        # Do the linker's work of replacing @loader_path by the directory the library that's using the dependency is in
        elsif linked =~ loader_path_regexp
          loader_path = File.dirname(current_library)
          possible_paths = [linked.sub("@loader_path", loader_path)]
        else
          possible_paths = [linked]
        end

        linked_present = possible_paths.any? { |path| path =~ install_dir_regexp }
      end

      if !safe && !linked_present
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

    #
    # Run healthchecks against aix.
    #
    # @return [Hash<String, Hash<String, Hash<String, Int>>>]
    #   the bad libraries (library_name -> dependency_name -> satisfied_lib_path -> count)
    #
    def health_check_aix
      current_library = nil
      bad_libs = {}

      yield_shellout_results("find #{project.install_dir}/ -type f | xargs file | grep \"RISC System\" | awk -F: '{print $1}' | xargs -n 1 ldd") do |line|
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
    # @return [Hash<String, Hash<String, Hash<String, Int>>>]
    #   the bad libraries (library_name -> dependency_name -> satisfied_lib_path -> count)
    #
    def health_check_ldd
      regexp_ends = ".*(" + IGNORED_ENDINGS.map { |e| e.gsub(/\./, '\.') }.join("|") + ")$"
      regexp_patterns = IGNORED_PATTERNS.map { |e| ".*" + e.gsub(/\//, '\/') + ".*" }.join("|")
      regexp = regexp_ends + "|" + regexp_patterns

      current_library = nil
      bad_libs = {}

      yield_shellout_results("find #{project.install_dir}/ -type f -regextype posix-extended ! -regex '#{regexp}' | xargs ldd") do |line|
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
    # This is the printf style format string to render a pointer/size_t on the
    # current platform.
    #
    # @return [String]
    #
    def hex
      windows_arch_i386? ? "0x%08x" : "0x%016x"
    end

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
    # Check the given path and library for "bad" libraries.
    #
    # @param [Hash<String, Hash<String, Hash<String, Int>>>]
    #   the bad libraries (library_name -> dependency_name -> satisfied_lib_path -> count)
    # @param [String]
    #   the library being analyzed
    # @param [String]
    #   dependency library name
    # @param [String]
    #   actual path of library satisfying the dependency
    #
    # @return the modified bad_library hash
    #
    def check_for_bad_library(bad_libs, current_library, name, linked)
      safe = nil

      whitelist_libs = case Ohai["platform"]
                       when "arch"
                         ARCH_WHITELIST_LIBS
                       when "mac_os_x"
                         MAC_WHITELIST_LIBS
                       when "solaris2"
                         SOLARIS_WHITELIST_LIBS
                       when "smartos"
                         SMARTOS_WHITELIST_LIBS
                       when "freebsd"
                         FREEBSD_WHITELIST_LIBS
                       when "aix"
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
