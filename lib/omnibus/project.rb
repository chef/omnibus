#
# omnibus project dsl reader
#
module Omnibus
  class Project
    include Rake::DSL

    PACKAGE_TYPES = ["deb", "rpm"]

    attr_reader :name
    attr_reader :description
    attr_reader :dependencies

    def initialize(io)
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

    private

    def render_tasks
      namespace :projects do
        shell = Mixlib::ShellOut.new("cp setup.sh /opt/opscode",
                                     :live_stream => STDOUT, 
                                     :cwd => './scripts')
        shell.run_command
        shell.error!
        PACKAGE_TYPES.each do |pkg_type|
          namespace @name do
            desc "package #{@name} into a #{pkg_type}"
            task pkg_type => (@dependencies.map {|dep| "software:#{dep}"}) do
              Dir.mkdir("pkg") unless File.exists?("pkg")
              command = ["fpm",
                   "-s dir",
                   "-t #{pkg_type}",
                   "-v 0.0.1",
                   "-n #{@name}",
                   "/opt/opscode",
                   "--post-install '../scripts/postinst'",
                   "--post-uninstall '../scripts/postrm'",
                   "-m 'Opscode, Inc.'",
                   "--description 'The full stack of #{@name}'",
                   "--url http://www.opscode.com"].join(" ")
              shell = Mixlib::ShellOut.new(command,
                                           :live_stream => STDOUT,
                                           :timeout => 3600,
                                           :cwd => './pkg')
              shell.run_command
              shell.error!
            end
          end
        end

        desc "package #{@name}"
        task @name => (PACKAGE_TYPES.map {|pkg_type| "projects:#{@name}:#{pkg_type}"})
      end
    end
  end
end
