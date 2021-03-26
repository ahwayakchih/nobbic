#!/bin/bash

if [ -z "$APP_NAME" ] ; then
    abort "ERROR: APP_NAME must be specified for backuper to know what data to backup"
fi

if ! podman pod exists ${APP_NAME} &>/dev/null ; then
	abort "ERROR: backuper could not find pod '${APP_NAME}'"
fi

export BACKUPS_DIR="$BACKUPS_DIR"
if [ -z "$BACKUPS_DIR" ] ; then
	export BACKUPS_DIR=$(pwd)"/backups"
	echo "WARNING: no BACKUPS_DIR specified, defaulting to '$BACKUPS_DIR'" >&2
fi

export BACKUP_NAME="$BACKUP_NAME"
if [ -z "$BACKUP_NAME" ] ; then
	NOW=$(date -u +%Y-%m-%dT%H-%M-%S)
	export BACKUP_NAME="${APP_NAME}_${NOW}"
	echo "WARNING: no BACKUP_NAME specified, defaulting to '$BACKUP_NAME'" >&2
fi

export BACKUP_PATH="${BACKUPS_DIR}/${BACKUP_NAME}"
mkdir -p "$BACKUP_PATH"

isRunning=$(podman pod ps --filter status=running --filter name="$APP_NAME" -q)

restart_after_backup() {
	local APP_NAME=$1
	echo "Backup process $(test ${EXIT_STATUS} -eq 0 && echo 'SUCCEEDED' || echo 'FAILED'), restarting ${APP_NAME} now..."\
		&& podman start "${APP_NAME}-nodebb"
}

stop_all_after_backup() {
	local APP_NAME=$1
	echo "Backup process $(test ${EXIT_STATUS} -eq 0 && echo 'SUCCEEDED' || echo 'FAILED')"\
		&& ${__APP} stop "$APP_NAME"
}

# We'll stop nodebb container, to be sure that no requests will go to database(s)
if [ -n "$isRunning" ] ; then
	echo "'$APP_NAME' is running, its NodeBB server will be stopped for the duration of making data backups... "
	podman stop "${APP_NAME}-nodebb" || abort "ERROR: Could not stop '${APP_NAME}-nodebb' container"
	on_exit restart_after_backup "$APP_NAME"
else
	# Make sure whole pod will remain stopped
	on_exit stop_all_after_backup "$APP_NAME"
fi

for CONTAINER in $(podman pod inspect "$APP_NAME" --format=$'{{range .Containers}}{{.Name}}\n{{end}}' | grep "^${APP_NAME}-") ; do
	backupBasename=${CONTAINER/$APP_NAME-/}
	toolName="${__SRC}/podman-backup-${backupBasename}.sh"
	export BACKUP_TO_FILE="${BACKUP_PATH}/${backupBasename}"
	if [ -f "$toolName" ] ; then
		echo "Backing up '${backupBasename}'"
		inline "$toolName" || abort "ERROR: backup of ${backupBasename} failed!"
	else
		echo "Skipping '${backupBasename}' - no backup script exists for it." >&2
	fi
	podman inspect "$CONTAINER" > "${BACKUP_PATH}/container-${backupBasename}.json" || abort "ERROR: failed to export information about ${backupBasename} container!"
done

podman pod inspect "$APP_NAME" > "${BACKUP_PATH}/pod.json" || abort "ERROR: failed to export information about ${APP_NAME} pod!"
