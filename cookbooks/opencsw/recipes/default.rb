
bash "download and install pkgutil" do
  user "root"
  cwd "/tmp"
  code <<-EOH
    echo "mail=
instance=overwrite
partial=nocheck
runlevel=nocheck
idepend=nocheck
rdepend=nocheck
space=nocheck
setuid=nocheck
conflict=nocheck
action=nocheck
basedir=default" > /tmp/noask
    rm -f pkgutil.pkg
    /usr/sfw/bin/wget http://mirror.opencsw.org/opencsw/pkgutil.pkg
    echo -e "all" | pkgadd -a noask -d pkgutil.pkg all
    /opt/csw/bin/pkgutil -U
  EOH
  not_if { ::File.exists?("/opt/csw/bin/pkgutil") }
end

