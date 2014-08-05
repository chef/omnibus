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
  class Packager::RPM < Packager::Base
    require 'find'

    attr_accessor :scripts

    validate do
      # Do not build an RPM if one with the same name already exists.
      !File.exist?(File.join(Config.package_dir, package_name))
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

      if File.exist?("#{project.package_scripts_path}/prerm")
        scripts[:before_remove] = File.join(project.package_scripts_path, 'prerm')
      end

      if File.exist?("#{project.package_scripts_path}/postrm")
        scripts[:after_remove] = File.join(project.package_scripts_path, 'postrm')
      end

      %w(BUILD RPMS SRPMS SOURCES SPECS).each { |d| create_directory(build_path(d)) }
    end

    build do
      run_rpm("#{package_name}")
    end

    clean do
      remove_directory(staging_path)
      remove_directory(build_path)
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

    #
    # Generate specfile entry for a file
    #
    def rpm_file_entry(file)
      original_file = file
      file = rpm_fix_name(file)
    end

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

    #
    # Create staging directory for building RPMs
    #
    def staging_path(path=nil)
      @staging_path ||= ::Dir.mktmpdir('package-rpm-staging') #, ::Dir.pwd)

      if path.nil?
        return @staging_path
      else
        return File.join(@staging_path, path)
      end
    end

    #
    # Create directory from which RPM will be built
    #
    def build_path(path=nil)
      @build_path ||= ::Dir.mktmpdir('package-rpm-build') #, ::Dir.pwd)

      if path.nil?
        return @build_path
      else
        return File.join(@build_path, path)
      end
    end

    #
    # Does the package contain the named script?
    #
    def script?(name)
      return scripts.include?(name)
    end

    #
    # Get the contents of an RPM package script by name
    #
    def script(script_name)
      scripts[script_name]
    end

    #
    # List all files in the staging_path (derived from fpm)
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
      Find.find(staging_path) \
        .select { |path| path != staging_path } \
        .select { |path| is_leaf.call(path) } \
        .collect { |path| path[staging_path.length + 1.. -1] }
    end

    #
    # Remove excluded files
    # @see {Omnibus::Project.exclude}
    #
    def exclude
      return if project.exclusions.empty?

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
    end

    #
    # Helper method for location of rpm packaging templates.
    #
    def template_dir
      File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "templates"))
    end

    #
    # @see {Packager::Base.render_template}
    #
    def render_template(src, dest)
      template_path = File.join(template_dir, src)
      template_code = File.read(template_path)
      erb = ERB.new(template_code, nil, "-")
      erb.filename = template_path
      content = erb.result(binding)
      File.write(dest, content)
    end

    #
    # Construct and run the rpmbuild command
    #
    def run_rpm(output_path)
      args = ["rpmbuild", "-bb"]
      args += ['--sign'] if Config.sign_rpm
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
          allconfigs << Pathname.new(p).relative_path_from(Pathname.new(staging_path)) if File.file? p
        end
      end
      allconfigs.sort!.uniq!

      # Prune excluded files
      exclude

      # sync files from staging to build
      destination = File.join(build_path, 'BUILD')
      FileSyncer.sync(staging_path, destination)

      render_template('rpm.erb', File.join(build_path("SPECS"), "#{package_name}.spec"))

      args << File.join(build_path("SPECS"), "#{package_name}.spec")

      if Config.sign_rpm
        if File.exist?("#{ENV['HOME']}/.rpmmacros")
          macros_home = ENV['HOME']
        else
          render_template('rpmmacros.erb', File.join(staging_path, '.rpmmacros'))
          macros_home = staging_path
        end
        build_cmd = args.join(' ')
        render_template('sign-rpm.erb', '/tmp/sign-rpm')
        File.chmod(0700, '/tmp/sign-rpm')
        script_cmd = "/tmp/sign-rpm \"#{build_cmd}\""
        begin
          execute(script_cmd, environment: { 'HOME' => macros_home })
        ensure
          remove_file('/tmp/sign-rpm')
        end
      else
        execute(args.join(' '))
      end

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
