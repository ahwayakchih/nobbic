#!/bin/bash

# WARNING: This script has to be run OUTSIDE container.
#          It's meant to add MongoDB to the specified pod.

__DIRNAME=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
source ${__DIRNAME}/common.sh
__APPDIR=$(dirname $__DIRNAME)

POD="$POD"
if [ -z "$POD" ] ; then
	echo "ERROR: POD name must be specified to add MongoDB to it" >&2
	exit 1
fi

if ! podman pod exists ${POD} ; then
	echo "ERROR: could not find pod '${POD}'" >&2
	exit 1
fi

CONTAINER="$CONTAINER"
if [ -z "$CONTAINER" ] ; then
	CONTAINER="${POD}-mongodb"
fi

MONGODB_IMAGE=${FROM_IMAGE:-docker.io/mongo:bionic}
if ! podman image exists "$MONGODB_IMAGE" ; then
	podman pull $PODMAN_PULL_ARGS_MONGODB "$MONGODB_IMAGE" || exit 1
fi

MONGODB_PORT=${CONTAINER_MONGODB_PORT:-$(podman inspect $MONGODB_IMAGE --format='{{range $key,$value := .Config.ExposedPorts}}{{$key}}\n{{end}}' | grep -m 1 -E '^[[:digit:]]*' | cut -d/ -f1 || test $? -eq 141)}
if [ -z "$MONGODB_PORT" ] ; then
	MONGODB_PORT=27017
	echo "WARNING: could not find port number exposed by $MONGODB_IMAGE, defaulting to $MONGODB_PORT" >&2
fi

MONGODB_ENV=$(get_env_values_for CONTAINER_ENV_MONGODB_ "")

# TODO: Setting up password does not seem to work (there are some errors while trying to connect) with official image
# local password=`tr -cd '[:alnum:]' < /dev/urandom | fold -w16 | head -n1 | fold -w4 | paste -sd\- -`

	# -e ${APP_SET_MONGODB_ENV_USER}="$podName" \
	# -e ${APP_SET_MONGODB_ENV_PASSWORD}="$password" \
podman create --pod "$POD" --name "$CONTAINER" $PODMAN_CREATE_ARGS_MONGODB \
	-e MONGO_INITDB_DATABASE="$POD" \
	-e CONTAINER_DATA_DIR="/data/"\
	$MONGODB_ENV "$MONGODB_IMAGE" >/dev/null || exit 1

# Import from backup, if specified
if [ ! -z "$RESTORE_FROM" ] && [ -f "${RESTORE_FROM}/mongodb.archive" ] ; then
	podman cp "${RESTORE_FROM}/mongodb.archive" ${CONTAINER}:/docker-entrypoint-initdb.d/restore-${POD}.archive
	podman cp "${__DIRNAME}/mongodb-restore-archive.sh" ${CONTAINER}:/docker-entrypoint-initdb.d/restore-archive.sh
fi

	# '-e CONTAINER_MONGODB_USERNAME=nodebb -e CONTAINER_MONGODB_PASSWORD='$password
echo "-e CONTAINER_MONGODB_HOST=localhost -e CONTAINER_MONGODB_PORT=$MONGODB_PORT -e CONTAINER_MONGODB_NAME=$POD"