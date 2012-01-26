#
# omnibus project dsl reader
#
module Omnibus
  class Project
    include Rake::DSL

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
        desc "package #{@name}"
        task @name => (@dependencies.map {|dep| "software:#{dep}"}) do
          command = ["fpm",
                     "-s dir",
                     "-t deb",
                     "-v 0.0.1",
                     "-n #{@name}",
                     "/opt/opscode",
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
  end
end
