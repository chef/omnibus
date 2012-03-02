#
# omnibus project dsl reader
#
module Omnibus
  class Project
    include Rake::DSL

    PACKAGE_TYPES = []

    attr_reader :name
    attr_reader :description
    attr_reader :dependencies

    def self.load(filename)
      new(IO.read(filename), filename)
    end

    def initialize(io, filename)
      @exclusions = Array.new
      case platform_family 
          when 'debian' 
            PACKAGE_TYPES << "deb"
          when 'fedora', 'rhel'
            PACKAGE_TYPES << "rpm"
      end
      instance_eval(io)
      render_tasks
    end

    def name(val)
      @name = val
    end

    def description(val)
      @description = val
    end

    def dependencies(val)
      @dependencies = val
    end

    def exclude(pattern)
      @exclusions << pattern
    end

    def platform_family
      OHAI.platform_family
    end

    def config
      Omnibus.config
    end

    def build_version
      Omnibus.build_version
    end

    def package_scripts_path
      "#{Omnibus.gem_root}/package-scripts"
    end

    private

    def render_tasks
      directory "pkg"

      namespace :projects do

        PACKAGE_TYPES.each do |pkg_type|
          namespace @name do
            desc "package #{@name} into a #{pkg_type}"
            task pkg_type => (@dependencies.map {|dep| "software:#{dep}"}) do
              if !File.exists?("#{config.install_dir}/setup.sh")
                shell = Mixlib::ShellOut.new("cp setup.sh #{config.install_dir}",
                                             :live_stream => STDOUT, 
                                             :cwd => package_scripts_path)
                shell.run_command
                shell.error!
              end

              # build the fpm command
              fpm_command = ["fpm",
                             "-s dir",
                             "-t #{pkg_type}",
                             "-v #{build_version}",
                             "-n #{@name}",
                             config.install_dir,
                             "--post-install '#{package_scripts_path}/postinst'",
                             "--post-uninstall '#{package_scripts_path}/postrm'",
                             "-m 'Opscode, Inc.'",
                             "--description 'The full stack of #{@name}'",
                             "--url http://www.opscode.com"]

              @exclusions.each do |pattern|
                fpm_command << "--exclude '#{pattern}'"
              end

              shell = Mixlib::ShellOut.new(fpm_command.join(" "),
                                           :live_stream => STDOUT,
                                           :timeout => 3600,
                                           :cwd => './pkg')
              shell.run_command
              shell.error!
            end

            task pkg_type => "pkg"
          end
        end

        desc "package #{@name}"
        task @name => (PACKAGE_TYPES.map {|pkg_type| "projects:#{@name}:#{pkg_type}"})
        task @name => "pkg"
      end
    end
  end
end
