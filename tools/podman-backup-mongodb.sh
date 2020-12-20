#!/bin/sh

# WARNING: This script has to be run OUTSIDE container.
#          It's meant to create backup of containers' data.

set -e
__DIRNAME=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

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
	echo "ERROR: BACKUP_TO_FILE ust be specified for backuper to know where to store data" >&2
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

podman exec -u mongodb $CONTAINER sh -c 'exec mongodump -d "'$MONGO_INITDB_DATABASE'" --archive' > "${targetName}.archive"

if [ -z "$isRunning" ] ; then
	echo -n "Backup done, starting '$CONTAINER' now..."
	podman stop "$CONTAINER"
fi
