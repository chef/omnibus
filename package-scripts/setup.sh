#!/bin/bash
#
# Perform necessary private-chef setup steps after package is installed.
#

PROGNAME=$(basename $0)

function error_exit
{
	echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
	exit 1
}

ln -sf /opt/opscode/bin/private-chef-ctl /usr/bin || error_exit "Cannot link private-chef-ctl in /usr/bin"
  
#  /opt/opscode/bin/private-chef-ctl reconfigure


echo "Thank you for installing Chef!"

exit 0
