require 'rake/clean'
CLEAN.include('/tmp/omnibus/**/*')
CLOBBER.include('/opt/opscode/**/*')

require 'ohai'
o = Ohai::System.new
o.require_plugin('os')
o.require_plugin('platform')
OHAI = o

require 'mixlib/shellout'

require 'omnibus/software'
require 'omnibus/project'

module Omnibus
  def self.github_user
    cmd = Mixlib::ShellOut.new("git", "config", "github.user")
    cmd.run_command
    cmd.error!
    cmd.stdout.strip
  end

  def self.github_token
    cmd = Mixlib::ShellOut.new("git", "config", "github.token")
    cmd.run_command
    cmd.error!
    cmd.stdout.strip
  end
end
