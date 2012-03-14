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

    def description(val=NULL_ARG)
      @description = val unless val.equal?(NULL_ARG)
      @description
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
      end
    end

    private

    def render_tasks
      directory config.package_dir

      namespace :projects do

        package_types.each do |pkg_type|
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
                                           :cwd => config.package_dir)
              shell.run_command
              shell.error!
            end

            task pkg_type => config.package_dir
          end
        end

        desc "package #{@name}"
        task @name => (package_types.map {|pkg_type| "projects:#{@name}:#{pkg_type}"})
        task @name => config.package_dir
      end
    end
  end
end
