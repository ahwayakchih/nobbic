#!/bin/sh

# WARNING: This script has to be run OUTSIDE container.
#          It's meant to add MongoDB to the specified pod.

set -e
__DIRNAME=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

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

# TODO: Setting up password does not seem to work (there are some errors while trying to connect) with official image
# local password=`tr -cd '[:alnum:]' < /dev/urandom | fold -w16 | head -n1 | fold -w4 | paste -sd\- -`

	# -e ${APP_SET_MONGODB_ENV_USER}="$podName" \
	# -e ${APP_SET_MONGODB_ENV_PASSWORD}="$password" \
podman run -d --pod "$POD" --name "$CONTAINER" \
	-e MONGO_INITDB_DATABASE="$POD" \
	-e CONTAINER_DATA_DIR="/data/"\
	"$MONGODB_IMAGE" >/dev/null || exit 1

	# '-e CONTAINER_MONGODB_USERNAME=nodebb -e CONTAINER_MONGODB_PASSWORD='$password
echo "-e CONTAINER_MONGODB_HOST=localhost -e CONTAINER_MONGODB_PORT=27017 -e CONTAINER_MONGODB_NAME=$POD"