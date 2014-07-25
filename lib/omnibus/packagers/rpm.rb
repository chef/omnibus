#
# Copyright:: Copyright (c) 2014 Chef Software, Inc.
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

# need to make sure rpmbuild is installed

module Omnibus
  #
  # Builds an rpm package
  #
  class Packager::Rpm < Packager::Base
    require 'find'

    attr_accessor :scripts

    validate do
    end

    setup do
      purge_directory(staging_dir)
      purge_directory(Config.package_dir)
      purge_directory(staging_resources_path)
      copy_directory(resources_path, staging_resources_path)

      # Sync the contents of /opt/chef to the staging directory
      create_directory(File.join(staging_path, project.install_dir))
      copy_directory(project.install_dir, File.join(staging_path, project.install_dir))

      # Implies that the full path is expected for extra_package_files.
      project.extra_package_files.each do |extra_file|
        dir = File.dirname(extra_file)
        create_directory(File.join(staging_path, dir))
        copy_directory(extra_file, File.join(staging_path, dir))
      end

      if File.exist?(File.join(project.package_scripts_path, 'preinst'))
        scripts[:before_install] = File.join(project.package_scripts_path, 'preinst')
      end

      if File.exist?("#{project.package_scripts_path}/postinst")
        scripts[:after_install] = File.join(project.package_scripts_path, 'postinst')
      end

      if File.exist?("#{package_scripts_path}/prerm")
        scripts[:before_remove] = File.join(package_scripts_path, 'prerm')
      end

      if File.exist?("#{package_scripts_path}/postrm")
        scripts[:after_remove] = File.join(package_scripts_path, 'postrm')
      end

      output_check(Config.package_dir)
      %w(BUILD RPMS SRPMS SOURCES SPECS).each { |d| create_directory(build_path(d)) }
    end

    build do
      run_rpm("#{package_name}")
    end

    clean do
      # nothing yet
    end

    # @see Base#package_name
    def package_name
      "#{project.package_name}-#{package_version(project.build_version)}-#{project.iteration}.#{Ohai['kernel']['machine']}.rpm"
    end

    def package_version(version)
      if !version.nil? and version.include?("-")
        version = version.gsub(/-/, "_")
      end
      version
    end

    ### Will need something like this to generate the file entry in the spec file
    def rpm_file_entry(file)
      original_file = file
      file = rpm_fix_name(file)
    end

    ### Will need something like this to straighten out the path names for rpm_file_entry
    # Fix path name
    # Replace [ with [\[] to make rpm not use globs
    # Replace * with [*] to make rpm not use globs
    # Replace ? with [?] to make rpm not use globs
    # Replace % with [%] to make rpm not expand macros
    def rpm_fix_name(name)
      name = "\"#{name}\"" if name[/\s/]
      name = name.gsub("[", "[\\[]")
      name = name.gsub("*", "[*]")
      name = name.gsub("?", "[?]")
      name = name.gsub("%", "[%]")
    end

    ### Will need something like this to create the staging directory
    def staging_path(path=nil)
      @staging_path ||= ::Dir.mktmpdir('package-rpm-staging') #, ::Dir.pwd)

      if path.nil?
        return @staging_path
      else
        return File.join(@staging_path, path)
      end
    end # def staging_path

    ### Will need something like this to create the build directory
    def build_path(path=nil)
      @build_path ||= ::Dir.mktmpdir('package-rpm-build') #, ::Dir.pwd)

      if path.nil?
        return @build_path
      else
        return File.join(@build_path, path)
      end
    end # def build_path

    # Does this package have the given script?
    def script?(name)
      return scripts.include?(name)
    end # def script?

    # Get the contents of the script by a given name.
    def script(script_name)
      scripts[script_name]
    end

    ### Will need something like this to populate the %files bit of the template
    # List all files in the staging_path
    #
    # The paths will all be relative to staging_path and will not include that
    # path.
    #
    # This method will emit 'leaf' paths. Files, symlinks, and other file-like
    # things are emitted. Intermediate directories are ignored, but
    # empty directories are emitted.
    def files
      is_leaf = lambda do |path|
        # True if this is a file/symlink/etc, but not a plain directory
        return true if !(File.directory?(path) and !File.symlink?(path))
        # Empty directories are leafs as well.
        return true if ::Dir.entries(path).sort == [".", ".."]
        # False otherwise (non-empty directory, etc)
        return false
      end # is_leaf

      # Find all leaf-like paths (files, symlink, empty directories, etc)
      # Also trim the leading path such that '#{staging_path}/' is removed from
      # the path before returning.
      #
      # Wrapping Find.find in an Enumerator is required for sane operation in ruby 1.8.7,
      # but requires the 'backports' gem (which is used in other places in fpm)
      # If omnibus does not support ruby 1.8.7, then we can get rid of the backports gem.
      return Enumerator.new { |y| Find.find(staging_path) { |path| y << path } } \
        .select { |path| path != staging_path } \
        .select { |path| is_leaf.call(path) } \
        .collect { |path| path[staging_path.length + 1.. -1] }
    end # def files

    ### Will need something like this to handle excludes:
    # remove the files during the input phase rather than deleting them here
    def exclude
      return if project.exclusions == []

      Find.find(staging_path) do |path|
        match_path = path.sub("#{staging_path.chomp('/')}/", '')

        project.exclusions.each do |wildcard|

          if File.fnmatch(wildcard, match_path)
            FileUtils.remove_entry_secure(path)
            Find.prune
            break
          end
        end
      end
    end # def exclude

    ### Will need something like this to generate the template
    def template_dir
      File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "templates"))
    end

    ### Can we use our render_template method?
    def template(path)
      template_path = File.join(template_dir, path)
      template_code = File.read(template_path)
      erb = ERB.new(template_code, nil, "-")
      erb.filename = template_path
      return erb
    end

    ### Will need something like this to verify files; structure is wrong
    def output_check(output_path)
      if !File.directory?(File.dirname(output_path))
        raise ParentDirectoryMissing.new(output_path)
      end
      if File.file?(output_path)
        raise "An RPM with the same name already exists at #{output_path}"
      end
    end # def output_check

    # I think we should bail on this in favor of doing a straight copy.
    # If we have to handle the case of symlinked files, then we can do it then.
    def copy_entry(src, dst)
      case File.ftype(src)
      # Ask SV how to handle this without ffi.
      # (bail on this for the moment, b/c I think including ffi is a thing)
      # when 'fifo', 'characterSpecial', 'blockSpecial', 'socket'
      #  st = File.stat(src)
      #  rc = mknod_w(dst, st.mode, st.dev)
      #  raise SystemCallError.new("mknod error", FFI.errno) if rc == -1
      when 'directory'
        FileUtils.mkdir(dst) unless File.exists? dst
      else
        # if the file with the same dev and inode has been copied already -
        # hard link it's copy to `dst`, otherwise make an actual copy
        st = File.lstat(src)
        known_entry = copied_entries[[st.dev, st.ino]]
        if known_entry
          FileUtils.ln(known_entry, dst)
        else
          FileUtils.copy_entry(src, dst)
          copied_entries[[st.dev, st.ino]] = dst
        end
      end # else...
    end # def copy_entry

    def copied_entries
      return @copied_entries ||= {}
    end # def copied_entries

    def run_rpm(output_path)
      args = ["rpmbuild", "-bb"]
      args += [
        "--define", "\'buildroot #{build_path}/BUILD\'",
        "--define", "\'_topdir #{build_path}\'",
        "--define", "\'_sourcedir #{build_path}\'",
        "--define", "\'_rpmdir #{build_path}/RPMS\'",
        "--define", "\'_tmppath /tmp\'"
      ]

      # scan all conf file paths for files and add them
      allconfigs = []
      project.config_files.each do |path|
        cfg_path = File.join(staging_path, path)
        raise "Config file path #{cfg_path} does not exist" unless File.exist?(cfg_path)
        Find.find(cfg_path) do |p|
          allconfigs << p.gsub("#{staging_path}/", '') if File.file? p
        end
      end
      allconfigs.sort!.uniq!

      #project.config_files = allconfigs.map { |x| File.join("/", x) }

      # Prune excluded files
      exclude

      # Copy files from staging directory to build directory.
      # We might not need to do the additional copy, since
      # we don't allow templated scripts, we are simplifying assumptions about links
      # and weird files; the only thing we do to staging is delete the excluded files.
      Find.find(staging_path) do |path|
        src = path.gsub(/^#{staging_path}/, '')
        dst = File.join(build_path, 'BUILD', src)
        copy_entry(path, dst)
      end

      rpmspec = template("rpm.erb").result(binding)
      specfile = File.join(build_path("SPECS"), "#{package_name}.spec")
      File.write(specfile, rpmspec)

      blob = `cat #{specfile}`
      puts "SPECFILE IS #{blob}"
      puts "END OF SPECFILE"

      args << specfile

      puts "ARGS is #{args.inspect}"

      execute(args.join(' '))

      ::Dir["#{build_path}/RPMS/**/*.rpm"].each do |rpmpath|
        FileUtils.cp(rpmpath, Config.package_dir)
      end
    end

    def initialize(project)
      super
      @scripts = {}
    end
  end
end
