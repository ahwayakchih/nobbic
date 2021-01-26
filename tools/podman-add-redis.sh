#!/bin/bash

# WARNING: This script has to be run OUTSIDE container.
#          It's meant to add Redis to the specified pod.

__DIRNAME=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
source ${__DIRNAME}/common.sh

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
if ! podman image exists "$REDIS_IMAGE" ; then
	podman pull $PODMAN_PULL_ARGS_REDIS "$REDIS_IMAGE" || exit 1
fi

REDIS_PORT=${CONTAINER_REDIS_PORT:-$(podman inspect $REDIS_IMAGE --format='{{range $key,$value := .Config.ExposedPorts}}{{$key}}\n{{end}}' | grep -m 1 -E '^[[:digit:]]*' | cut -d/ -f1 || test $? -eq 141)}
if [ -z "$REDIS_PORT" ] ; then
	REDIS_PORT=6379
	echo "WARNING: could not find port number exposed by $REDIS_IMAGE, defaulting to $REDIS_PORT" >&2
fi

REDIS_ENV=$(get_env_values_for CONTAINER_ENV_REDIS_ "")

# We do not set CONTAINER_DATA_DIR, because, for now, Redis is used only for temporary data
# and does not persist data between restarts.

podman create --pod "$POD" --name "$CONTAINER" $PODMAN_CREATE_ARGS_REDIS \
	$REDIS_ENV "$REDIS_IMAGE" >/dev/null || exit 1

echo '-e CONTAINER_REDIS_HOST=localhost -e CONTAINER_REDIS_PORT='$REDIS_PORT
