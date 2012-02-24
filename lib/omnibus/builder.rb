module Omnibus
  class Builder

    attr_reader :build_commands
    attr_reader :project_dir

    def initialize(build_commands, project_dir)
      @build_commands = build_commands
      @project_dir    = project_dir
    end

    def log(message)
      puts "[builder] #{message}"
    end

    def build
      log "building the source"
      @build_commands.each do |cmd|
        execute(cmd)
      end
    end

    def execute(cmd)
      shell = nil
      cmd_args = Array(cmd)
      options = {
        :cwd => project_dir,
        :live_stream => STDOUT,
        :timeout => 3600
      }
      if cmd_args.last.is_a? Hash
        cmd_options = cmd_args.last
        cmd_args[cmd_args.size - 1] = options.merge(cmd_options)
      else
        cmd_args << options
      end
      shell = Mixlib::ShellOut.new(*cmd)
      shell.run_command
      shell.error!
    rescue Exception
      pp :builder => self
      unless shell.nil?
        pp :shell => shell
      end
      raise
    end

  end
end
