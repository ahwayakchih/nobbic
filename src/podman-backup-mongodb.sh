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

MONGODB_ARCHIVE=$(readlink -f "$BACKUP_TO_FILE")

isRunning=$(podman ps --filter status=running --filter name='^'$CONTAINER'$' -q)

if [ -z "$isRunning" ] ; then
	echo -n "'$CONTAINER' is not running, it will be started for the duration of making data backups... "
	podman start "$CONTAINER" || return 1
fi

containerEnv=$(podman inspect "$CONTAINER" --format=$'{{range .Config.Env}}{{.}}\n{{end}}')
MONGO_INITDB_DATABASE=$(echo "$containerEnv" | grep "MONGO_INITDB_DATABASE" | cut -d= -f2)
MONGODB_HOSTNAME=$(echo "$containerEnv" | grep "HOSTNAME" | cut -d= -f2)

MONGODB_IMAGE=$(podman inspect "$CONTAINER" --format='{{.ImageName}}')
MONGODB_PORT=${CONTAINER_MONGODB_PORT:-$(podman inspect $MONGODB_IMAGE --format=$'{{range $key,$value := .Config.ExposedPorts}}{{$key}}\n{{end}}' | grep -m 1 -E '^[[:digit:]]*' | cut -d/ -f1 || test $? -eq 141)}
if [ -z "$MONGODB_PORT" ] ; then
	MONGODB_PORT=27017
	echo "WARNING: could not find port number exposed by ${MONGODB_IMAGE}, defaulting to ${MONGODB_PORT}" >&2
fi

echo "Waiting for MongoDB from '$MONGODB_HOSTNAME' to be available on port $MONGODB_PORT..."
podman run --rm --pod "$MONGODB_HOSTNAME" -v "${__DIRNAME}/.container/tools:/tools:ro" docker.io/alpine /tools/wait-for.sh "localhost:${MONGODB_PORT}" -t 30 -l >&2\
	|| (echo "ERROR: timeout while waiting for database to be ready" >&2 && exit 1)\
	|| return 1
podman exec $CONTAINER sh -c 'exec mongodump -d "'$MONGO_INITDB_DATABASE'" --archive' > "${MONGODB_ARCHIVE}.archive"\
	&& echo "MongoDB backup done"

if [ -z "$isRunning" ] ; then
	echo -n "Stopping '${CONTAINER}' now... "
	podman stop "$CONTAINER" && echo "done" || echo "failed"
fi
