#!/bin/bash

# WARNING: This script has to be run OUTSIDE container.
#          It's meant to add Redis to the specified pod.

# Remember our stdout, so we can bring it back later
exec 4>&1

# Redirect stdout to stderr, just in case something slips through
# so it will not break our result.
exec 1>&2

__DIRNAME=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
source ${__DIRNAME}/common.sh

POD="$POD"
if [ -z "$POD" ] ; then
	echo "ERROR: POD name must be specified to add local NodeBB to it" >&2
	exit 1
fi

if [ -z "$CONTAINER" ] ; then
	CONTAINER="${POD}-nodebb"
fi

# Prepare NodeBB image
imageNameFile=$(mktemp)
env IMAGE_NAME_FILE="$imageNameFile" APP_NAME="$POD" tools/podman-create-nodebb.sh || return 1
NODEBB_IMAGE=$(cat "$imageNameFile")
rm "$imageNameFile"
if [ -z "$NODEBB_IMAGE" ] ; then
	echo "ERROR: could not get NodeBB container image name" >&2
	return 1
fi

NODEBB_PORT=${CONTAINER_NODEBB_PORT:-$(podman image inspect $NODEBB_IMAGE --format='{{range $key,$value := .Config.ExposedPorts}}{{$key}}\n{{end}}' | grep -m 1 -E '^[[:digit:]]*' | cut -d/ -f1 || test $? -eq 141)}
if [ -z "$NODEBB_PORT" ] ; then
	NODEBB_PORT=4567
	echo "WARNING: could not find port number exposed by $NODEBB_IMAGE, defaulting to $NODEBB_PORT" >&2
fi

NODEBB_ENV=$(get_env_values_for CONTAINER_ENV_NODEBB_ "")$(get_env_values_for CONTAINER_ENV_NODE_ NODE_)

if [ -z "$CONTAINER_APP_DNS_ALIAS" ] && [ -z "$CONTAINER_APP_DNS" ] ; then
	echo $NODEBB_ENV | grep CONTAINER_APP_DNS || (
		echo "WARNING: no CONTAINER_APP_DNS_ALIAS nor CONTAINER_APP_DNS was specified" >&2
		echo "         OpenDNS service will be used to get public IP when running the pod" >&2
	)
	# TODO: set to "localhost" by default?
elif [ -n "$CONTAINER_APP_DNS_ALIAS" ] ; then
	NODEBB_ENV="$NODEBB_ENV -e CONTAINER_APP_DNS_ALIAS=$CONTAINER_APP_DNS_ALIAS"
else
	NODEBB_ENV="$NODEBB_ENV -e CONTAINER_APP_DNS=$CONTAINER_APP_DNS"
fi

if [ "$CONTAINER_NODEJS_IP" ] ; then
	NODEBB_ENV="$NODEBB_ENV -e CONTAINER_NODEJS_IP=${CONTAINER_NODEJS_IP}"
fi

PODMAN_CREATE_ARGS="$PODMAN_CREATE_ARGS $PODMAN_CREATE_ARGS_NODEBB"

podman create --pod "$POD" --name "$CONTAINER" $PODMAN_CREATE_ARGS \
	$NODEBB_ENV "$NODEBB_IMAGE" >/dev/null || exit 1

# Import from backup, if specified
BACKUP_DATA="${RESTORE_FROM}/nodebb.tar"
if [ ! -z "$RESTORE_FROM" ] && [ -f "$BACKUP_DATA" ] ; then
	echo -n "Copying $BACKUP_DATA to NodeBB container... "
	podman cp "$BACKUP_DATA" ${CONTAINER}:/app/nodebb-$(basename "$RESTORE_FROM").tar || (echo "failed" && exit 1) || return 1
	echo "done"
fi

# Restore stdout and close 4 that was storing its file descriptor
exec 1>&4-

# Output result
echo ''
