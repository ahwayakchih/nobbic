#!/bin/sh

# WARNING: This script has to be run OUTSIDE container.
#          It's meant to create backup of containers' data.

set -e
__DIRNAME=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

APP_NAME="$APP_NAME"
if [ -z "$APP_NAME" ] ; then
    echo "ERROR: APP_NAME must be specified for backuper to know what data to backup" >&2
    exit 1
fi

if ! podman pod exists ${APP_NAME} ; then
	echo "ERROR: backuper could not find pod '${APP_NAME}'" >&2
	exit 1
fi

BACKUPS_DIR="$BACKUPS_DIR"
if [ -z "$BACKUPS_DIR" ] ; then
	echo "WARNING: no BACKUPS_DIR specified, defaulting to './backups'" >&2
	BACKUPS_DIR=$(pwd)"/backups"
fi

BACKUP_NAME="$BACKUP_NAME"
if [ -z "$BACKUP_NAME" ] ; then
	BACKUP_NAME=$(date -u +%Y-%m-%dT%H-%M-%S)
	echo "WARNING: no BACKUP_NAME specified, defaulting to '$BACKUP_NAME'" >&2
fi

targetName=$(readlink -f "${BACKUPS_DIR}/${APP_NAME}_${BACKUP_NAME}")
mkdir -p "$targetName"

isRunning=$(podman pod ps --filter status=running --filter name="$APP_NAME" -q)

if [ ! -z "$isRunning" ] ; then
	echo -n "'$APP_NAME' is running, it will be stopped for the duration of making data backups... "
	${__DIRNAME}/../app stop "$APP_NAME" || exit 1
fi

for container in $(podman pod inspect "$APP_NAME" --format='{{range .Containers}}{{.Name}}\n{{end}}' | grep "^${APP_NAME}-") ; do
	toolname="${__DIRNAME}/podman-backup-${container/$APP_NAME-/}.sh"
	if [ -f "$toolname" ] ; then
		CONTAINER=$container BACKUP_TO_FILE="${targetName}/${CONTAINER}" "$toolname" || true
	else
		dataDir=$(podman inspect "$container" --format='{{range .Config.Env}}{{.}}\n{{end}}'| grep CONTAINER_DATA_DIR | cut -d= -f2)
		if [ ! -z "$dataDir" ] ; then
			podman run --rm --volumes-from $container:ro -v $targetName:/backup docker.io/alpine tar cvf "/backup/${container}.tar" "$dataDir"
		fi
	fi
done

if [ ! -z "$isRunning" ] ; then
	echo -n "Backup done, restarting '$APP_NAME' now..."
	${__DIRNAME}/../app start "$APP_NAME"
else
	${__DIRNAME}/../app stop "$APP_NAME"
fi