#!/bin/bash

# WARNING: This script has to be run OUTSIDE container.
#          It's meant to add MongoDB to the specified pod.

set -e
__DIRNAME=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
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

# TODO: Setting up password does not seem to work (there are some errors while trying to connect) with official image
# local password=`tr -cd '[:alnum:]' < /dev/urandom | fold -w16 | head -n1 | fold -w4 | paste -sd\- -`

	# -e ${APP_SET_MONGODB_ENV_USER}="$podName" \
	# -e ${APP_SET_MONGODB_ENV_PASSWORD}="$password" \
podman run -d --pod "$POD" --name "$CONTAINER" \
	-e MONGO_INITDB_DATABASE="$POD" \
	-e CONTAINER_DATA_DIR="/data/"\
	"$MONGODB_IMAGE" >/dev/null || exit 1

MONGODB_PORT=27017

# Import from backup, if specified
if [ ! -z "$RESTORE_FROM" ] && [ -f "${RESTORE_FROM}/mongodb.archive" ] ; then
	podman run --rm --pod "$POD" -v "${__APPDIR}/.container/tools:/tools:ro" docker.io/alpine /tools/wait-for.sh "localhost:${MONGODB_PORT}" -t 20 >&2 || exit 1

	containerEnv=$(podman inspect "$CONTAINER" --format='{{range .Config.Env}}{{.}}\n{{end}}')
	MONGO_INITDB_DATABASE=$(echo "$containerEnv" | grep "MONGO_INITDB_DATABASE" | cut -d= -f2)

	podman exec -i -u mongodb $CONTAINER sh -c 'exec mongorestore -d "'$MONGO_INITDB_DATABASE'" --archive' < "${RESTORE_FROM}/mongodb.archive" >&2 || exit 1
fi

	# '-e CONTAINER_MONGODB_USERNAME=nodebb -e CONTAINER_MONGODB_PASSWORD='$password
echo "-e CONTAINER_MONGODB_HOST=localhost -e CONTAINER_MONGODB_PORT=$MONGODB_PORT -e CONTAINER_MONGODB_NAME=$POD"