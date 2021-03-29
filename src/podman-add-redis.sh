#!/bin/bash

if ! podman pod exists ${APP_NAME} &>/dev/null ; then
	echo "ERROR: could not find pod '${APP_NAME}'" >&2
	return 1
fi

DEFAULT_REDIS_PORT=6379

if [[ "$APP_ADD_REDIS" =~ ^redis:\/\/ ]] ; then
	inline db_url.sh
	set_db_envs_from_url "$APP_ADD_REDIS" REDIS_
	if [ -n "$REDIS_HOST" ] ; then
		# Output result
		export PODMAN_CREATE_ARGS_NODEBB="-e CONTAINER_REDIS_HOST=${REDIS_HOST}\
			-e CONTAINER_REDIS_PORT=${REDIS_PORT:-$DEFAULT_REDIS_PORT}\
			-e CONTAINER_REDIS_DB=${REDIS_NAME}\
			-e CONTAINER_REDIS_PASSWORD=${REDIS_PASSWORD}\
			${PODMAN_CREATE_ARGS_NODEBB}"
		# TODO: support restoring from backup?
		# Return early
		return
	fi
fi

REDIS_CONTAINER=${CONTAINER:-"${APP_NAME}-redis"}

REDIS_IMAGE=${FROM_IMAGE:-docker.io/redis:alpine}
if ! podman image exists "$REDIS_IMAGE" &>/dev/null ; then
	podman pull $PODMAN_PULL_ARGS_REDIS "$REDIS_IMAGE" >/dev/null || exit 1
fi

REDIS_PORT=${CONTAINER_REDIS_PORT:-$(podman inspect $REDIS_IMAGE --format=$'{{range $key,$value := .Config.ExposedPorts}}{{$key}}\n{{end}}' | grep -m 1 -E '^[[:digit:]]*' | cut -d/ -f1 || test $? -eq 141)}
if [ -z "$REDIS_PORT" ] ; then
	REDIS_PORT=$DEFAULT_REDIS_PORT
	echo "WARNING: could not find port number exposed by ${REDIS_IMAGE}, defaulting to ${REDIS_PORT}" >&2
fi

REDIS_ENV=$(get_env_values_for CONTAINER_ENV_REDIS_ "")

REDIS_CREATE_ARGS="${PODMAN_CREATE_ARGS} ${PODMAN_CREATE_ARGS_REDIS}"

podman create --pod "$APP_NAME" --name "$REDIS_CONTAINER" $REDIS_CREATE_ARGS \
	$REDIS_ENV "$REDIS_IMAGE" $CONTAINER_CMD_REDIS >/dev/null || exit 1

# Import from backup, if specified
if [ ! -z "$RESTORE_FROM" ] ; then
	REDIS_PREVIOUS_IMAGE=""
	if [ -f "${RESTORE_FROM}/container-redis.json" ] ; then
		REDIS_PREVIOUS_IMAGE=$(get_image_name_from_json "${RESTORE_FROM}/container-redis.json")
		if [ "${REDIS_PREVIOUS_IMAGE%%:*}" = "${REDIS_IMAGE%%:*}" ] ; then
			echo "Loading ${RESTORE_FROM}/redis.env"
			# Try to import REDIS_DATA_DIR from backed up env, but ignore any failure
			import "${RESTORE_FROM}/redis.env" '^REDIS_DATA_DIR$'
		fi
	fi

	# Since we may be trying to restore data to some different redis image, with different setup,
	# it would be good to get data dir from its config. And to do that, we would need to have it running.
	# But starting added container, seems to hangs whole script, and starting new one with same command
	# then waiting for db to be ready... too much code for one stupid value.
	# TODO: find good solution, or simply ecourage writing custom scripts for redis.
	for f in $(find ${RESTORE_FROM}/redis-* -type f 2>/dev/null || echo '') ; do
		name=$(basename $f)
		name=${name/redis-/}
		test -n "$name" || continue

		if [ -z "$REDIS_DATA_DIR" ] ; then
			REDIS_DATA_DIR='/data'
			echo "WARNING: could not find REDIS_DATA_DIR, using default ${REDIS_DATA_DIR}" >&2
		fi
		echo "Restoring data from ${f} to ${REDIS_CONTAINER}:${REDIS_DATA_DIR}/${name}" >&2
		podman cp "$f" ${REDIS_CONTAINER}:${REDIS_DATA_DIR}/${name} >&2\
			|| (echo "ERROR: could not restore data for Redis" >&2 && exit 1)\
			|| return 1
	done
fi

# Output result
export PODMAN_CREATE_ARGS_NODEBB="-e CONTAINER_REDIS_HOST=localhost\
	-e CONTAINER_REDIS_PORT=${REDIS_PORT}\
	${PODMAN_CREATE_ARGS_NODEBB}"
