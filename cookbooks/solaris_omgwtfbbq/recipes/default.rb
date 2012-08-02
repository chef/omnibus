
# make solaris produce less rageface

return unless node['platform'] == "solaris2"

include_recipe "opencsw"

%w{gmake ggrep coreutils gtar}.each do |pkg|
  opencsw pkg
end

link "/opt/csw/bin/make" do
  to "/opt/csw/bin/gmake"
end
link "/opt/csw/bin/tar" do
  to "/opt/csw/bin/gtar"
end
link "/opt/csw/bin/install" do
  to "/opt/csw/bin/ginstall"
end
link "/opt/csw/bin/grep" do
  to "/opt/csw/bin/ggrep"
end
link "/opt/csw/bin/egrep" do
  to "/opt/csw/bin/gegrep"
end
link "/opt/csw/bin/fgrep" do
  to "/opt/csw/bin/gfgrep"
end

template "/.profile" do
  source "root-profile"
  owner "root"
  group "root"
  mode "0600"
end

