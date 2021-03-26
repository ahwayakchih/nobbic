#!/bin/sh

export USER=${USER:-$(id -un)}
export GROUP=${GROUP:-$(id -gn)}
export APP_NAME

if [ -z "$APP_NAME" ] ; then
	echo "ERROR: APP_NAME name must be specified to generate init service file to it" >&2
	return 1
fi

if ! podman pod exists "$APP_NAME" ; then
	echo "ERROR: '$APP_NAME' pod does not exists" >&2
	return 1
fi

# Try OpenRC first
if (command -v rc || command -v openrc) &>/dev/null ; then
	inline host-install-service-openrc.sh || return $?
	return 0
fi

# Try SystemD second
if command -v systemctl &>/dev/null ; then
	inline host-install-service-systemd.sh || return $?
	return 0
fi

echo "ERROR: unknown init system" >&2
return 1
