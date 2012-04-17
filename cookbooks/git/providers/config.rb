require 'chef/shell_out'

action :set do
  cmd = git_config(@new_resource.key)
  if cmd.exitstatus != 0 || cmd.stdout.strip != @new_resource.value
    cmd = git_config(@new_resource.key, @new_resource.value)
    cmd.error!
    @new_resource.updated_by_last_action(true)
  end
end

action :unset do
  cmd = git_config(@new_resource.key)
  if cmd.exitstatus != 1
    cmd = git_config("--unset", @new_resource.key)
    cmd.error!
    @new_resource.updated_by_last_action(true)
  end
end

private

def shell_opts
  {
    :user => @new_resource.user,
    :cwd => @new_resource.cwd,
    :environment => {
      'HOME' => ::File.expand_path("~#{@new_resource.user}")
    }
  }
end

def git_config(*args)
  args = ["git", "config", @new_resource.file_scope] + args + [shell_opts]
  cmd = Chef::ShellOut.new(*args)
  cmd.run_command
  cmd
end
