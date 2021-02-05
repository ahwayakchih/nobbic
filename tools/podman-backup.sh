#!/bin/bash

# WARNING: This script has to be run OUTSIDE container.
#          It's meant to create backup of containers' data.

__DIRNAME=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
source ${__DIRNAME}/common.sh

APP_NAME="$APP_NAME"
if [ -z "$APP_NAME" ] ; then
    fail "ERROR: APP_NAME must be specified for backuper to know what data to backup"
fi

if ! podman pod exists ${APP_NAME} ; then
	fail "ERROR: backuper could not find pod '${APP_NAME}'"
fi

BACKUPS_DIR="$BACKUPS_DIR"
if [ -z "$BACKUPS_DIR" ] ; then
	BACKUPS_DIR=$(pwd)"/backups"
	echo "WARNING: no BACKUPS_DIR specified, defaulting to '$BACKUPS_DIR'" >&2
fi

BACKUP_NAME="$BACKUP_NAME"
if [ -z "$BACKUP_NAME" ] ; then
	NOW=$(date -u +%Y-%m-%dT%H-%M-%S)
	BACKUP_NAME="${APP_NAME}_${NOW}"
	echo "WARNING: no BACKUP_NAME specified, defaulting to '$BACKUP_NAME'" >&2
fi

targetName="${BACKUPS_DIR}/${BACKUP_NAME}"
mkdir -p "$targetName"

isRunning=$(podman pod ps --filter status=running --filter name="$APP_NAME" -q)

# We'll stop nodebb container, to be sure that no requests will go to database(s)
if [ ! -z "$isRunning" ] ; then
	echo "'$APP_NAME' is running, it will be stopped for the duration of making data backups... "
	podman stop "${APP_NAME}-nodebb" || fail "Could not stop '${APP_NAME}-nodebb' container"
	trap "echo 'Backup process '\$(test \$? -eq 0 && echo 'SUCCEEDED' || echo 'FAILED')', restarting $APP_NAME now...' && podman start '${APP_NAME}-nodebb'" EXIT
else
	# Make sure whole pod will remain stopped
	trap "${__DIRNAME}/../app stop '$APP_NAME'" EXIT
fi

for container in $(podman pod inspect "$APP_NAME" --format='{{range .Containers}}{{.Name}}\n{{end}}' | grep "^${APP_NAME}-") ; do
	backupBasename=${container/$APP_NAME-/}
	toolName="${__DIRNAME}/podman-backup-${backupBasename}.sh"
	if [ -f "$toolName" ] ; then
		CONTAINER=$container BACKUP_TO_FILE="${targetName}/${backupBasename}" "$toolName" || fail "ERROR: backup of ${backupBasename} failed!"
	else
		echo "WARNING: no backup script exists for '${backupBasename}'" >&2
	fi
	podman inspect "$container" > "${targetName}/container-${backupBasename}.json" || fail "ERROR: failed to export information about ${backupBasename} container!"
done

podman pod inspect "$APP_NAME" > "${targetName}/pod.json" || fail "ERROR: failed to export information about ${APP_NAME} pod!"
