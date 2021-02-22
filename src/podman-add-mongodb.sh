#!/bin/bash

if ! podman pod exists ${APP_NAME} &>/dev/null ; then
	echo "ERROR: could not find pod '${APP_NAME}'" >&2
	return 1
fi

DEFAULT_MONGODB_PORT=27017

if [[ "$APP_ADD_MONGODB" =~ ^mongo(db)?:\/\/ ]] ; then
	inline db_url.sh
	set_db_envs_from_url "$APP_ADD_MONGODB" MONGODB_
	if [ -n "$MONGODB_HOST" ] ; then
		# Output result
		export PODMAN_CREATE_ARGS_NODEBB="-e CONTAINER_MONGODB_HOST=${MONGODB_HOST}\
			-e CONTAINER_MONGODB_PORT=${MONGODB_PORT:-$DEFAULT_MONGODB_PORT}\
			-e CONTAINER_MONGODB_NAME=${MONGODB_NAME}\
			-e CONTAINER_MONGODB_USER=${MONGODB_USER}\
			-e CONTAINER_MONGODB_PASSWORD=${MONGODB_PASSWORD}\
			${PODMAN_CREATE_ARGS_NODEBB}"
		# TODO: support restoring from backup?
		# Return early
		return
	fi
fi

MONGODB_CONTAINER=${CONTAINER:-"${APP_NAME}-mongodb"}

MONGODB_IMAGE=${FROM_IMAGE:-docker.io/mongo:bionic}
if ! podman image exists "$MONGODB_IMAGE" &>/dev/null ; then
	podman pull $PODMAN_PULL_ARGS_MONGODB "$MONGODB_IMAGE" >/dev/null || return 1
fi

MONGODB_PORT=${CONTAINER_MONGODB_PORT:-$(podman image inspect $MONGODB_IMAGE --format=$'{{range $key,$value := .Config.ExposedPorts}}{{$key}}\n{{end}}' | grep -m 1 -E '^[[:digit:]]*' | cut -d/ -f1 || test $? -eq 141)}
if [ -z "$MONGODB_PORT" ] ; then
	MONGODB_PORT=$DEFAULT_MONGODB_PORT
	echo "WARNING: could not find port number exposed by ${MONGODB_IMAGE}, defaulting to ${MONGODB_PORT}" >&2
fi

MONGODB_ENV=$(get_env_values_for CONTAINER_ENV_MONGODB_ "")

MONGODB_NAME=$CONTAINER_ENV_MONGODB_MONGO_INITDB_DATABASE
if [ -z "$MONGODB_NAME" ] ; then
	MONGODB_NAME="$APP_NAME"
	MONGODB_ENV="-e MONGO_INITDB_DATABASE=${MONGODB_NAME} ${MONGODB_ENV}"
fi

# TODO: Setting up password does not seem to work (there are some errors while trying to connect) with official image
# local password=`tr -cd '[:alnum:]' < /dev/urandom | fold -w16 | head -n1 | fold -w4 | paste -sd\- -`

MONGODB_CREATE_ARGS="${PODMAN_CREATE_ARGS} ${PODMAN_CREATE_ARGS_MONGODB}"

	# -e ${APP_SET_MONGODB_ENV_USER}="$APP_NAME" \
	# -e ${APP_SET_MONGODB_ENV_PASSWORD}="$password" \
podman create --pod "$APP_NAME" --name "$MONGODB_CONTAINER" $MONGODB_CREATE_ARGS \
	$MONGODB_ENV "$MONGODB_IMAGE" $CONTAINER_CMD_MONGODB >/dev/null || exit 1

# Import from backup, if specified
if [ ! -z "$RESTORE_FROM" ] && [ -f "${RESTORE_FROM}/mongodb.archive" ] ; then
	podman cp "${RESTORE_FROM}/mongodb.archive" ${MONGODB_CONTAINER}:/docker-entrypoint-initdb.d/restore-${APP_NAME}.archive >/dev/null || exit 1
	podman cp "${__TOOLS}/mongodb-restore-archive.sh" ${MONGODB_CONTAINER}:/docker-entrypoint-initdb.d/restore-archive.sh >/dev/null || exit 1
fi

# Output result
	# '-e CONTAINER_MONGODB_USERNAME=nodebb -e CONTAINER_MONGODB_PASSWORD='$password
export PODMAN_CREATE_ARGS_NODEBB="-e CONTAINER_MONGODB_HOST=localhost\
	-e CONTAINER_MONGODB_PORT=${MONGODB_PORT}\
	-e CONTAINER_MONGODB_NAME=${MONGODB_NAME}\
	${PODMAN_CREATE_ARGS_NODEBB}"
