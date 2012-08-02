
action :install do
  pkg = new_resource.package_name
  bash "install #{pkg} from opencsw" do
    user "root"
    cwd "/tmp"
    code <<-EOH
      /opt/csw/bin/pkgutil -y -i #{pkg}
    EOH
    not_if { `/opt/csw/bin/pkgutil -l #{pkg}` =~ /CSW/ }  # always returns 0
  end
end

