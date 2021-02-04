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
	echo "ERROR: POD name must be specified to add NGINX to it" >&2
	exit 1
fi

if [ -z "$CONTAINER" ] ; then
	CONTAINER="${POD}-nginx"
fi

NGINX_IMAGE=${FROM_IMAGE:-docker.io/nginx:alpine}
if ! podman image exists "$NGINX_IMAGE" ; then
	podman pull $PODMAN_PULL_ARGS_NGINX "$NGINX_IMAGE" >/dev/null || exit 1
fi

if [ "$NGINX_IMAGE" != "$FROM_IMAGE" ] ; then
	PODMAN_CREATE_ARGS_NGINX="-v ${POD}-data:/data:ro $PODMAN_CREATE_ARGS_NGINX"
fi

NGINX_PORT=${CONTAINER_NGINX_PORT:-$(podman image inspect $NGINX_IMAGE --format='{{range $key,$value := .Config.ExposedPorts}}{{$key}}\n{{end}}' | grep -m 1 -E '^[[:digit:]]*' | cut -d/ -f1 || test $? -eq 141)}
if [ -z "$NGINX_PORT" ] ; then
	# This is default NGINX's port
	if [ "$NGINX_IMAGE" != "$FROM_IMAGE" ] ; then
		NGINX_PORT=8080
		echo "WARNING: could not find port number exposed by $NGINX_IMAGE, defaulting to $NGINX_PORT" >&2
	else
		echo "ERROR: could not find port number exposed by $NGINX_IMAGE" >&2
	fi
fi

NGINX_ENV=$(get_env_values_for CONTAINER_ENV_NGINX_ "")

PODMAN_CREATE_ARGS="$PODMAN_CREATE_ARGS $PODMAN_CREATE_ARGS_NGINX"

podman create --pod "$POD" --name "$CONTAINER" --add-host=localhost:127.0.0.1 $PODMAN_CREATE_ARGS \
	$NGINX_ENV "$NGINX_IMAGE" || exit 1

configFileName=$(mktemp)
env APP_USE_FQDN=${APP_USE_FQDN:-localhost} ${__DIRNAME}/handlebar.sh ${__DIRNAME}/nginx-nodebb.conf.handlebarsh > $configFileName
podman cp "$configFileName" "${CONTAINER}:/etc/nginx/conf.d/default.conf"
rm "$configFileName"

# Restore stdout and close 4 that was storing its file descriptor
exec 1>&4-

# Output result
echo "-v ${POD}-data:/data:z"
