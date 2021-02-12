#!/bin/bash

NPM_CONTAINER=${CONTAINER:-"${APP_NAME}-npm"}

NPM_IMAGE=${FROM_IMAGE:-docker.io/verdaccio/verdaccio}
if ! podman image exists "$NPM_IMAGE" ; then
	podman pull $PODMAN_PULL_ARGS_NPM "$NPM_IMAGE" >/dev/null || exit 1
fi

if [ "$NPM_IMAGE" != "$FROM_IMAGE" ] ; then
	PODMAN_CREATE_ARGS_NPM="-v ${NPM_CONTAINER}:/verdaccio/storage:z ${PODMAN_CREATE_ARGS_NPM}"
fi

NPM_PORT=${CONTAINER_NPM_PORT:-$(podman image inspect $NPM_IMAGE --format=$'{{range $key,$value := .Config.ExposedPorts}}{{$key}}\n{{end}}' | grep -m 1 -E '^[[:digit:]]*' | cut -d/ -f1 || test $? -eq 141)}
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

NPM_CREATE_ARGS="${PODMAN_CREATE_ARGS} ${PODMAN_CREATE_ARGS_NPM}"

podman create --pod "$APP_NAME" --name "$NPM_CONTAINER" $NPM_CREATE_ARGS \
	$NPM_ENV "$NPM_IMAGE" >/dev/null || return 1

# Output result
export PODMAN_CREATE_ARGS_NODEBB="-e NPM_CONFIG_REGISTRY=http://localhost:${NPM_PORT}\
	${PODMAN_CREATE_ARGS_NODEBB}"
