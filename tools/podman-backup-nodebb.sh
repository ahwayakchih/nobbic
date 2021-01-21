#!/bin/bash

# WARNING: This script has to be run OUTSIDE container.
#          It's meant to create backup of containers' data.

__DIRNAME=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
source ${__DIRNAME}/common.sh

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

isRunning=$(podman ps --filter status=running --filter name='^$CONTAINER$' -q)

if [ ! -z "$isRunning" ] ; then
	echo -n "'$CONTAINER' is running, it will be stopped for the duration of making data backups... "
	podman stop "$CONTAINER" || exit 1
fi

podman inspect "$CONTAINER" --format='{{range .Config.Env}}{{.}}\n{{end}}' | grep -E "(NODE(BB)?_|CONTAINER_)"  > "${targetName}.env"
CONTAINER_DATA_DIR=$(cat "${targetName}.env" | grep "CONTAINER_DATA_DIR" | cut -d= -f2)

podman run --rm --volumes-from $CONTAINER:ro\
	-v $__DIRNAME:/tools:ro\
	-v $targetDir:/backup:rw\
	-e CONTAINER_DATA_DIR="$CONTAINER_DATA_DIR"\
	-e BACKUP_TO_FILE="/backup/$targetFile"\
	docker.io/alpine /tools/alpine-backup-nodebb.sh

if [ ! -z "$isRunning" ] ; then
	echo -n "Backup done, restarting '$CONTAINER' now..."
	podman start "$CONTAINER"
fi