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

containerEnv=$(podman inspect "$CONTAINER" --format='{{range .Config.Env}}{{.}}\n{{end}}')
MONGO_INITDB_DATABASE=$(echo "$containerEnv" | grep "MONGO_INITDB_DATABASE" | cut -d= -f2)
MONGODB_HOSTNAME=$(echo "$containerEnv" | grep "HOSTNAME" | cut -d= -f2)

MONGODB_IMAGE=$(podman inspect "$CONTAINER" --format='{{.ImageName}}')
MONGODB_PORT=${CONTAINER_MONGODB_PORT:-$(podman inspect $MONGODB_IMAGE --format='{{range $key,$value := .Config.ExposedPorts}}{{$key}}\n{{end}}' | grep -m 1 -E '^[[:digit:]]*' | cut -d/ -f1 || test $? -eq 141)}
if [ -z "$MONGODB_PORT" ] ; then
	MONGODB_PORT=27017
	echo "WARNING: could not find port number exposed by $MONGODB_IMAGE, defaulting to $MONGODB_PORT" >&2
fi

echo "Waiting for MongoDB from '$MONGODB_HOSTNAME' to be available on port $MONGODB_PORT..."
podman run --rm --pod "$MONGODB_HOSTNAME" -v "${__APPDIR}/.container/tools:/tools:ro" docker.io/alpine /tools/wait-for.sh "localhost:${MONGODB_PORT}" -t 30 -l >&2\
	|| (echo "ERROR: timeout while waiting for database to be ready" >&2 && exit 1)\
	|| exit 1
podman exec -u mongodb $CONTAINER sh -c 'exec mongodump -d "'$MONGO_INITDB_DATABASE'" --archive' > "${targetName}.archive"

if [ -z "$isRunning" ] ; then
	echo -n "Backup done, stopping '$CONTAINER' now..."
	podman stop "$CONTAINER"
fi
