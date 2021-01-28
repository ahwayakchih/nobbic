#!/bin/bash

# WARNING: This script has to be run OUTSIDE container.
#          It's meant to create backup of containers' data.

__DIRNAME=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
source ${__DIRNAME}/common.sh
__APPDIR=$(dirname $__DIRNAME)

CONTAINER="$CONTAINER"
if [ -z "$CONTAINER" ] ; then
    echo "ERROR: CONTAINER must be specified for backuper to know what to backup" >&2
    exit 1
fi

if ! podman container exists ${CONTAINER} ; then
	echo "ERROR: backuper could not find container '${CONTAINER}'" >&2
	exit 1
fi

BACKUP_TO_FILE="$BACKUP_TO_FILE"
if [ -z "$BACKUP_TO_FILE" ] ; then
	echo "ERROR: BACKUP_TO_FILE must be specified for backuper to know where to store data" >&2
	exit 1
fi

targetName=$(readlink -f "$BACKUP_TO_FILE")
targetDir=$(dirname $targetName)
targetFile=$(basename $targetName)

isRunning=$(podman ps --filter status=running --filter name='^'$CONTAINER'$' -q)

if [ -z "$isRunning" ] ; then
	echo -n "'$CONTAINER' is not running, it will be started for the duration of making data backups... "
	podman start "$CONTAINER" || exit 1
fi

POSTGRES_IMAGE=$(podman inspect "$CONTAINER" --format='{{.ImageName}}')
POSTGRES_PORT=${CONTAINER_POSTGRES_PORT:-$(podman inspect $POSTGRES_IMAGE --format='{{range $key,$value := .Config.ExposedPorts}}{{$key}}\n{{end}}' | grep -m 1 -E '^[[:digit:]]*' | cut -d/ -f1 || test $? -eq 141)}
if [ -z "$POSTGRES_PORT" ] ; then
	POSTGRES_PORT=5432
	echo "WARNING: could not find port number exposed by $POSTGRES_IMAGE, defaulting to $POSTGRES_PORT" >&2
fi

containerEnv=$(podman inspect "$CONTAINER" --format='{{range .Config.Env}}{{.}}\n{{end}}')
POSTGRES_DB=$(echo "$containerEnv" | grep "POSTGRES_DB" | cut -d= -f2)
POSTGRES_HOSTNAME=$(echo "$containerEnv" | grep "HOSTNAME" | cut -d= -f2)

podman run --rm --pod "$POSTGRES_HOSTNAME" -v "${__APPDIR}/.container/tools:/tools:ro" docker.io/alpine /tools/wait-for.sh "localhost:${POSTGRES_PORT}" -t 30 >&2 || exit 1
podman exec -t -u postgres $CONTAINER /bin/bash -c 'pg_dump -d "'$POSTGRES_DB'"' > "${targetName}.txt"

if [ -z "$isRunning" ] ; then
	echo -n "Backup done, stopping '$CONTAINER' now..."
	podman stop "$CONTAINER"
fi