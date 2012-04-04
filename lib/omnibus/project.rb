#
# omnibus project dsl reader
#
module Omnibus
  class Project
    include Rake::DSL

    NULL_ARG = Object.new

    attr_reader :dependencies

    def self.load(filename)
      new(IO.read(filename), filename)
    end

    def initialize(io, filename)
      @exclusions = Array.new
      instance_eval(io)
      render_tasks
    end

    def name(val=NULL_ARG)
      @name = val unless val.equal?(NULL_ARG)
      @name
    end

    def iteration
      if platform_family == 'rhel'
        platform_version =~ /^(\d+)/
        maj = $1
        return "1.el#{maj}"
      end
      return "1.#{platform}.#{platform_version}"
    end

    def description(val=NULL_ARG)
      @description = val unless val.equal?(NULL_ARG)
      @description
    end

    def replaces(val=NULL_ARG)
      @replaces = val unless val.equal?(NULL_ARG)
      @replaces
    end

    def dependencies(val)
      @dependencies = val
    end

    def exclude(pattern)
      @exclusions << pattern
    end

    def platform_version
      OHAI.platform_version
    end

    def platform
      OHAI.platform
    end

    def platform_family
      OHAI.platform_family
    end

    def config
      Omnibus.config
    end

    def build_version
      Omnibus::BuildVersion.full
    end

    def package_scripts_path
      "#{Omnibus.root}/package-scripts/#{name}"
    end

    def package_types
      case platform_family 
      when 'debian' 
        [ "deb" ]
      when 'fedora', 'rhel'
        [ "rpm" ]
      else
        []
      end
    end

    private

    def render_tasks
      directory config.package_dir
      directory "pkg"

      namespace :projects do

        package_types.each do |pkg_type|
          namespace @name do
            desc "package #{@name} into a #{pkg_type}"
            task pkg_type => (@dependencies.map {|dep| "software:#{dep}"}) do

              # build the fpm command
              fpm_command = ["fpm",
                             "-s dir",
                             "-t #{pkg_type}",
                             "-v #{build_version}",
                             "-n #{@name}",
                             "--iteration #{iteration}",
                             config.install_dir,
                             "--post-install '#{package_scripts_path}/postinst'",
                             "--pre-uninstall '#{package_scripts_path}/prerm'",
                             "--post-uninstall '#{package_scripts_path}/postrm'",
                             "-m 'Opscode, Inc.'",
                             "--description 'The full stack of #{@name}'",
                             "--url http://www.opscode.com"]

              @exclusions.each do |pattern|
                fpm_command << "--exclude '#{pattern}'"
              end
              fpm_command << " --replaces #{@replaces}" if @replaces

              shell = Mixlib::ShellOut.new(fpm_command.join(" "),
                                           :live_stream => STDOUT,
                                           :timeout => 3600,
                                           :cwd => config.package_dir)
              shell.run_command
              shell.error!
            end

            task pkg_type => config.package_dir
          end
        end

        task "#{@name}:copy" => (package_types.map {|pkg_type| "#{@name}:#{pkg_type}"}) do
          cp_cmd = "cp #{config.package_dir}/* pkg/"
          shell = Mixlib::ShellOut.new(cp_cmd)
          shell.run_command
          shell.error!
        end
        task "#{@name}:copy" => "pkg"

        desc "package #{@name}"
        task @name => "#{@name}:copy"
      end
    end
  end
end
