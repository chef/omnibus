#!/bin/bash
#
# Install a full Opscode Client
#

PROGNAME=$(basename $0)
INSTALLER_DIR=$(dirname $0)

function error_exit
{
	echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
	exit 1
}

validation_key=
organization=
chef_url=

while getopts o:u:v: opt
do
    case "$opt" in
      v)  validation_key="$OPTARG";;
      o)  organization="$OPTARG"; chef_url="https://api.opscode.com/organizations/$OPTARG";;
      u)  chef_url="$OPTARG";;
      \?)		# unknown flag
      	  echo >&2 \
            "usage: $0 [-v validation_key] ([-o organization] || [-u url]) "
	  exit 1;;
    esac
done
shift `expr $OPTIND - 1`


mkdir -p /opt/opscode || error_exit "Cannot create /opt/opscode!"
if [ -f "/usr/bin/sw_vers" ]; then
    # OS X -- Use DYLD_LIBRARY_PATH
    DYLD_LIBRARY_PATH=$INSTALLER_DIR/embedded/lib $INSTALLER_DIR/embedded/bin/rsync -a --delete --exclude $INSTALLER_DIR/setup.sh $INSTALLER_DIR/ /opt/opscode || error_exit "Cannot rsync release to /opt/opscode"
else
    LD_LIBRARY_PATH=$INSTALLER_DIR/embedded/lib $INSTALLER_DIR/embedded/bin/rsync -a --delete --exclude $INSTALLER_DIR/setup.sh $INSTALLER_DIR/ /opt/opscode || error_exit "Cannot rsync release to /opt/opscode"
fi

if [ "" != "$chef_url" ]; then
  mkdir -p /etc/chef || error_exit "Cannot create /etc/chef!"
  (
  cat <<'EOP'
log_level :info
log_location STDOUT
EOP
  ) > /etc/chef/client.rb
  if [ "" != "$chef_url" ]; then
    echo "chef_server_url '${chef_url}'" >> /etc/chef/client.rb
  fi
  if [ "" != "$organization" ]; then
    echo "validation_client_name '${organization}-validator'" >> /etc/chef/client.rb
  fi
  chmod 644 /etc/chef/client.rb
fi

if [ "" != "$validation_key" ]; then
  cp $validation_key /etc/chef/validation.pem || error_exit "Cannot copy the validation key!"
  chmod 600 /etc/chef/validation.pem
fi

ln -sf /opt/opscode/bin/chef-client /usr/bin || error_exit "Cannot link chef-client to /usr/bin"
ln -sf /opt/opscode/bin/chef-solo /usr/bin || error_exit "Cannot link chef-solo to /usr/bin"
ln -sf /opt/opscode/bin/knife /usr/bin || error_exit "Cannot link knife to /usr/bin"
ln -sf /opt/opscode/bin/shef /usr/bin || error_exit "Cannot link shef to /usr/bin"
ln -sf /opt/opscode/bin/ohai /usr/bin || error_exit "Cannot link ohai to /usr/bin"
if [ -h /opt/opscode/bin/chef-server-ctl ]; then
  ln -sf /opt/opscode/bin/chef-server-ctl /usr/bin || error_exit "Cannot link chef-server-ctl to /usr/bin"
  /usr/bin/chef-server-ctl reconfigure
fi

echo "Thank you for installing Chef!"

exit 0
