#!/bin/bash

if [ -z "$CONTAINER" ] ; then
    echo "ERROR: CONTAINER must be specified for backuper to know what to backup" >&2
    return 1
fi

if ! podman container exists ${CONTAINER} &>/dev/null ; then
	echo "ERROR: backuper could not find container '${CONTAINER}'" >&2
	return 1
fi

if [ -z "$BACKUP_TO_FILE" ] ; then
	echo "ERROR: BACKUP_TO_FILE must be specified for backuper to know where to store data" >&2
	return 1
fi

isRunning=$(podman ps --filter status=running --filter name='^'$CONTAINER'$' -q)

if [ -z "$isRunning" ] ; then
	echo -n "'$CONTAINER' is not running, it will be started for the duration of making data backups... "
	podman start "$CONTAINER" || return 1
fi

REDIS_IMAGE=$(podman inspect "$CONTAINER" --format='{{.ImageName}}')
REDIS_PORT=${CONTAINER_REDIS_PORT:-$(podman inspect $REDIS_IMAGE --format='{{range $key,$value := .Config.ExposedPorts}}{{$key}}\n{{end}}' | grep -m 1 -E '^[[:digit:]]*' | cut -d/ -f1 || test $? -eq 141)}
if [ -z "$REDIS_PORT" ] ; then
	REDIS_PORT=6379
	echo "WARNING: could not find port number exposed by ${REDIS_IMAGE}, defaulting to ${REDIS_PORT}" >&2
fi

REDIS_HOSTNAME=$(podman inspect "$CONTAINER" --format='{{range .Config.Env}}{{.}}\n{{end}}' | grep "HOSTNAME" | cut -d= -f2)

echo "Waiting for Redis from '$REDIS_HOSTNAME' to be available on port $REDIS_PORT..."
podman run --rm --pod "$REDIS_HOSTNAME" -v "${__DIRNAME}/.container/tools:/tools:ro" docker.io/alpine /tools/wait-for.sh "localhost:${REDIS_PORT}" -t 30 -l >&2\
	|| (echo "ERROR: timeout while waiting for database to be ready" >&2 && exit 1)\
	|| return 1

function redis () {
	local cmd="redis-cli --raw $@"
	podman exec "$CONTAINER" /bin/sh -c "$cmd"
}

REDIS_DATA_DIR=$(redis config get dir | tail -n 1)
REDIS_FILE_RDB=$(redis config get dbfilename | tail -n 1)
REDIS_FILE_AOF=$(redis config get appendfilename | tail -n 1)
REDIS_AOF_ENABLED=$(redis config get appendonly | tail -n 1)

if [ -z "$isRunning" ] ; then
	echo -n "Stopping '${CONTAINER}' now... "
	podman stop "$CONTAINER" >/dev/null && echo "done" || echo "failed"
fi

if [ -n "$REDIS_FILE_RDB" ] ; then
	REDIS_FILE="$REDIS_FILE_RDB"
elif [ -n "$REDIS_FILE_AOF" ] ; then
	REDIS_FILE="$REDIS_FILE_AOF"
else
	echo "ERROR: could not find info about Redis data storage" >&2
	return 1
fi

REDIS_ARCHIVE="${BACKUP_TO_FILE}-${REDIS_FILE}"

echo "Copying ${CONTAINER}:${REDIS_DATA_DIR}/${REDIS_FILE} to ${REDIS_ARCHIVE}"
podman cp "${CONTAINER}:${REDIS_DATA_DIR}/${REDIS_FILE}" ${REDIS_ARCHIVE} \
	|| (echo "ERROR: Could not copy ${CONTAINER}:${REDIS_DATA_DIR}/${REDIS_FILE} to ${REDIS_ARCHIVE}" >&2 && exit 1)\
	|| return 1

echo "Redis backup done"