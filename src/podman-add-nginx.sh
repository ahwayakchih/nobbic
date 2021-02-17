#!/bin/bash

if ! podman pod exists ${APP_NAME} &>/dev/null ; then
	echo "ERROR: could not find pod '${APP_NAME}'" >&2
	return 1
fi

NGINX_CONTAINER=${CONTAINER:-"${APP_NAME}-nginx"}

NGINX_IMAGE=${FROM_IMAGE:-docker.io/nginx:alpine}
if ! podman image exists "$NGINX_IMAGE" ; then
	podman pull $PODMAN_PULL_ARGS_NGINX "$NGINX_IMAGE" >/dev/null || return 1
fi

export NGINX_NODEBB_ROOT='/nodebb'
PODMAN_CREATE_ARGS_NGINX="-v ${APP_NAME}-nodebb-build:${NGINX_NODEBB_ROOT}/build:ro\
	-v ${APP_NAME}-nodebb-public:${NGINX_NODEBB_ROOT}/public:ro\
	${PODMAN_CREATE_ARGS_NGINX}"

# NGINX_PORT=${CONTAINER_NGINX_PORT:-$(podman image inspect $NGINX_IMAGE --format=$'{{range $key,$value := .Config.ExposedPorts}}{{$key}}\n{{end}}' | grep -m 1 -E '^[[:digit:]]*' | cut -d/ -f1 || test $? -eq 141)}
# if [ -z "$NGINX_PORT" ] ; then
# 	# This is default NGINX's port
# 	if [ "$NGINX_IMAGE" != "$FROM_IMAGE" ] ; then
# 		NGINX_PORT=80
# 		echo "WARNING: could not find port number exposed by $NGINX_IMAGE, defaulting to $NGINX_PORT" >&2
# 	else
# 		echo "ERROR: could not find port number exposed by $NGINX_IMAGE" >&2
# 	fi
# fi

NGINX_ENV=$(get_env_values_for CONTAINER_ENV_NGINX_ "")

PODMAN_CREATE_ARGS="${PODMAN_CREATE_ARGS} ${PODMAN_CREATE_ARGS_NGINX}"

podman create --pod "$APP_NAME" --name "$NGINX_CONTAINER" $PODMAN_CREATE_ARGS \
	$NGINX_ENV "$NGINX_IMAGE" $CONTAINER_CMD_NGINX || return 1

configFileName="${APP_NAME}.nginx.conf"
generate nginx.conf.handlebarsh $configFileName || return 1
podman cp "$configFileName" "${NGINX_CONTAINER}:/etc/nginx/conf.d/default.conf" >/dev/null\
	&& rm "$configFileName"
