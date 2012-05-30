execute "install homebrew" do
  command "curl -sfL https://github.com/mxcl/homebrew/tarball/master | tar zx -m --strip 1"
  cwd "/usr/local"
  not_if { File.exist? '/usr/local/bin/brew' }
end

file "/usr/local/bin/brew" do
  owner "root"
end

package 'git'

execute "update homebrew from github" do
  command "/usr/local/bin/brew update || true"
end
