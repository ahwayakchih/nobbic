#!/bin/sh

# WARNING: This script has to be OUTSIDE container.
#          It tries to find out which init system is used and then run script for that system.

__DIRNAME=$(cd $(dirname $(readlink -f $0)) &>/dev/null && pwd -P)
set -e

export __APP=$(realpath ${__DIRNAME}/../app)
export USER=${USER:-$(id -un)}
export GROUP=${GROUP:-$(id -gn)}

if [ -z "$APP_NAME" ] ; then
	echo "ERROR: APP_NAME name must be specified to generate init service file to it" >&2
	exit 1
fi

# Try OpenRC first
if (command -v rc || command -v openrc) &>/dev/null ; then
	source ${__DIRNAME}/os-install-service-openrc.sh
	exit 0
fi

# Try SystemD second
if command -v systemctl &>/dev/null ; then
	source ${__DIRNAME}/os-install-service-systemd.sh
	exit 0
fi

echo "ERROR: unknown init system" >&2
exit 1
