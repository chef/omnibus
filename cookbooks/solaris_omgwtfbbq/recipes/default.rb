
# make solaris produce less rageface

return unless node['platform'] == "solaris2"

include_recipe "opencsw"

%w{gmake ggrep coreutils gtar}.each do |pkg|
  opencsw pkg
end

bash "symlinks for using gnu utilities on solaris" do
  code <<-EOH
    ln -s /opt/csw/bin/gmake /opt/csw/bin/make
    ln -s /opt/csw/bin/gtar /opt/csw/bin/tar
    ln -s /opt/csw/bin/ginstall /opt/csw/bin/install
    ln -s /opt/csw/bin/ggrep /opt/csw/bin/grep
    ln -s /opt/csw/bin/gegrep /opt/csw/bin/egrep
    ln -s /opt/csw/bin/gfgrep /opt/csw/bin/fgrep
  EOH
end

template "/.profile" do
  source "root-profile"
  owner "root"
  group "root"
  mode "0600"
end

