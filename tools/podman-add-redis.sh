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
__APPDIR=$(dirname $__DIRNAME)

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
	podman pull $PODMAN_PULL_ARGS_REDIS "$REDIS_IMAGE" >/dev/null || exit 1
fi

REDIS_PORT=${CONTAINER_REDIS_PORT:-$(podman inspect $REDIS_IMAGE --format='{{range $key,$value := .Config.ExposedPorts}}{{$key}}\n{{end}}' | grep -m 1 -E '^[[:digit:]]*' | cut -d/ -f1 || test $? -eq 141)}
if [ -z "$REDIS_PORT" ] ; then
	REDIS_PORT=6379
	echo "WARNING: could not find port number exposed by $REDIS_IMAGE, defaulting to $REDIS_PORT" >&2
fi

REDIS_ENV=$(get_env_values_for CONTAINER_ENV_REDIS_ "")

PODMAN_CREATE_ARGS="$PODMAN_CREATE_ARGS $PODMAN_CREATE_ARGS_REDIS"

podman create --pod "$POD" --name "$CONTAINER" $PODMAN_CREATE_ARGS \
	$REDIS_ENV "$REDIS_IMAGE" >/dev/null || exit 1

# Import from backup, if specified
if [ ! -z "$RESTORE_FROM" ] ; then
	# Since we may be trying to restore data to some different redis image, with different setup,
	# it would be good to get data dir from its config. And to do that, we would need to have it running.
	# But starting added container, seems to hangs whole script, and starting new one with same command
	# then waiting for db to be ready... too much code for one stupid value.
	# TODO: find good solution, or simply ecourage writing custom scripts for redis.

	REDIS_DATA_DIR="/data"
	for f in ${RESTORE_FROM}/redis-* ; do
		name=$(basename $f)
		name=${name/redis-/}
		echo "Restoring data from ${f} to ${CONTAINER}:${REDIS_DATA_DIR}/${name}" >&2
		podman cp "$f" ${CONTAINER}:${REDIS_DATA_DIR}/${name} >&2 || echo "ERROR: could not restore data for Redis" >&2
	done
fi

# Restore stdout and close 4 that was storing its file descriptor
exec 1>&4-

# Output result
echo '-e CONTAINER_REDIS_HOST=localhost -e CONTAINER_REDIS_PORT='$REDIS_PORT
