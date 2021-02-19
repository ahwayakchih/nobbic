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

POSTGRES_ARCHIVE=$(readlink -f "$BACKUP_TO_FILE")

isRunning=$(podman ps --filter status=running --filter name='^'$CONTAINER'$' -q)

if [ -z "$isRunning" ] ; then
	echo -n "'$CONTAINER' is not running, it will be started for the duration of making data backups... "
	podman start "$CONTAINER" || return 1
fi

POSTGRES_IMAGE=$(podman inspect "$CONTAINER" --format='{{.ImageName}}')
POSTGRES_PORT=${CONTAINER_POSTGRES_PORT:-$(podman inspect $POSTGRES_IMAGE --format=$'{{range $key,$value := .Config.ExposedPorts}}{{$key}}\n{{end}}' | grep -m 1 -E '^[[:digit:]]*' | cut -d/ -f1 || test $? -eq 141)}
if [ -z "$POSTGRES_PORT" ] ; then
	POSTGRES_PORT=5432
	echo "WARNING: could not find port number exposed by ${POSTGRES_IMAGE}, defaulting to ${POSTGRES_PORT}" >&2
fi

containerEnv=$(podman inspect "$CONTAINER" --format=$'{{range .Config.Env}}{{.}}\n{{end}}')
POSTGRES_DB=$(echo "$containerEnv" | grep "POSTGRES_DB" | cut -d= -f2)
POSTGRES_HOSTNAME=$(echo "$containerEnv" | grep "HOSTNAME" | cut -d= -f2)

echo "Waiting for PostgreSQL from '$POSTGRES_HOSTNAME' to be available on port $POSTGRES_PORT..."
podman run --rm --pod "$POSTGRES_HOSTNAME" -v "${__DIRNAME}/.container/tools:/tools:ro" docker.io/alpine /tools/wait-for.sh "127.0.0.1:${POSTGRES_PORT}" -t 30 -l >&2\
	|| (echo "ERROR: timeout while waiting for database to be ready" >&2 && exit 1)\
	|| return 1
echo "Running pg_dump inside ${CONTAINER} and redirecting its output to ${POSTGRES_ARCHIVE}.txt"
podman exec -t -u postgres $CONTAINER /bin/bash -c 'pg_dump -d "'$POSTGRES_DB'"' > "${POSTGRES_ARCHIVE}.txt"\
	&& echo "PostgreSQL backup done"

if [ -z "$isRunning" ] ; then
	echo -n "Stopping '${CONTAINER}' now... "
	podman stop "$CONTAINER" >/dev/null && echo "done" || echo "failed"
fi