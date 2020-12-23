#!/bin/sh

# WARNING: This script has to be run OUTSIDE container.
#          It's meant to add Redis to the specified pod.

set -e
__DIRNAME=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

POD="$POD"
if [ -z "$POD" ] ; then
	echo "ERROR: POD name must be specified to add Redis to it" >&2
	exit 1
fi

if ! podman pod exists ${POD} ; then
	echo "ERROR: could not find pod '${POD}'" >&2
	exit 1
fi

CONTAINER="$CONTAINER"
if [ -z "$CONTAINER" ] ; then
	CONTAINER="${POD}-redis"
fi

REDIS_IMAGE=${FROM_IMAGE:-docker.io/redis:alpine3.12}

# We do not set CONTAINER_DATA_DIR, because, for now, Redis is used only for temporary data
# and does not persist data between restarts.

podman run -d --pod "$POD" --name "$CONTAINER" \
	"$REDIS_IMAGE" >/dev/null || exit 1

echo '-e CONTAINER_REDIS_HOST=localhost -e CONTAINER_REDIS_PORT=27017'
