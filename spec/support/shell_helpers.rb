require "mixlib/shellout"

module Omnibus
  module RSpec
    module ShellHelpers
      def shellout!(command, options = {})
        cmd = Mixlib::ShellOut.new(command, options)
        cmd.environment["HOME"] = "/tmp" unless ENV["HOME"]
        cmd.run_command
        cmd
      end
    end
  end
end
