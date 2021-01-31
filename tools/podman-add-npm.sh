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
	echo "ERROR: POD name must be specified to add local NPM to it" >&2
	exit 1
fi

if [ -z "$CONTAINER" ] ; then
	CONTAINER="${POD}-npm"
fi

NPM_IMAGE=${FROM_IMAGE:-docker.io/verdaccio/verdaccio}
if ! podman image exists "$NPM_IMAGE" ; then
	# if [ -z "$FROM_IMAGE" ] ; then
	# 	NODE_VERSION=14
	# 	env APP_NAME=nodebb-node NODE_VERSION=$NODE_VERSION ./tools/podman-create-nodeapp.sh

	# 	podman run --replace --name build-${NPM_IMAGE} -v ${__DIRNAME}:/tools:ro nodebb-node:$NODE_VERSION /bin/bash -c "npm install -g verdaccio"\
	# 		&& podman commit \
	# 			-c CMD=/bin/bash\
	# 			-c EXPOSE=4873 \
	# 			-c USER=node \
	# 			-c WORKDIR=/app \
	# 			-c ENV=ENV=/etc/profile \
	# 			-e ENV=CONTAINER_DATA_DIR=/home/node/.config/verdaccio/storage \
	# 			build-${NPM_IMAGE} "$NPM_IMAGE" \
	# 		&& podman rm build-${NPM_IMAGE}
	# else
		podman pull $PODMAN_PULL_ARGS_NPM "$NPM_IMAGE" >/dev/null || exit 1
	# fi
fi

if [ "$NPM_IMAGE" != "$FROM_IMAGE" ] ; then
	PODMAN_CREATE_ARGS_NPM="-v nodebb-npm:/verdaccio/storage:z $PODMAN_CREATE_ARGS_NPM"
fi

NPM_PORT=${CONTAINER_NPM_PORT:-$(podman image inspect $NPM_IMAGE --format='{{range $key,$value := .Config.ExposedPorts}}{{$key}}\n{{end}}' | grep -m 1 -E '^[[:digit:]]*' | cut -d/ -f1 || test $? -eq 141)}
if [ -z "$NPM_PORT" ] ; then
	# This is default Verdaccio's port
	if [ "$NPM_IMAGE" != "$FROM_IMAGE" ] ; then
		NPM_PORT=4873
		echo "WARNING: could not find port number exposed by $NPM_IMAGE, defaulting to $NPM_PORT" >&2
	else
		echo "ERROR: could not find port number exposed by $NPM_IMAGE" >&2
	fi
fi

NPM_ENV=$(get_env_values_for CONTAINER_ENV_NPM_ "")

PODMAN_CREATE_ARGS="$PODMAN_CREATE_ARGS $PODMAN_CREATE_ARGS_NPM"

podman create --pod "$POD" --name "$CONTAINER" --add-host=localhost:127.0.0.1 $PODMAN_CREATE_ARGS \
	$NPM_ENV "$NPM_IMAGE" || exit 1

# Restore stdout and close 4 that was storing its file descriptor
exec 1>&4-

# Output result
echo '-e NPM_CONFIG_REGISTRY="http://localhost:'$NPM_PORT'"'