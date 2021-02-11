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

NODEBB_FILE=$(readlink -f "$BACKUP_TO_FILE")
NODEBB_ARCHIVE=$(basename $NODEBB_FILE)

isRunning=$(podman ps --filter status=running --filter name='^'$CONTAINER'$' -q)

if [ ! -z "$isRunning" ] ; then
	echo -n "'$CONTAINER' is running, it will be stopped for the duration of making data backups... "
	podman stop "$CONTAINER" || return 1
fi

# TODO: export all env variables, so additional custom settings are not lost.
podman inspect "$CONTAINER" --format='{{range .Config.Env}}{{.}}\n{{end}}' | grep -E "^(NODE(BB)?_|CONTAINER_|APP_|PORT)"  > "${NODEBB_FILE}.env"
CONTAINER_REPO_DIR=$(cat "${NODEBB_FILE}.env" | grep "CONTAINER_REPO_DIR" | cut -d= -f2)

podman run --rm --volumes-from $CONTAINER:ro\
	-v ${__TOOLS}/alpine-backup-nodebb.sh:/usr/local/bin/alpine-backup-nodebb.sh:ro\
	-v ${BACKUP_PATH}:/backup:rw\
	-e CONTAINER_REPO_DIR="${CONTAINER_REPO_DIR}"\
	-e BACKUP_TO_FILE="/backup/${NODEBB_ARCHIVE}"\
	docker.io/alpine alpine-backup-nodebb.sh\
	&& podman cp "${CONTAINER}:/app/POD_BUILD_ENV" "${BACKUP_PATH}/pod.env"\
	&& echo "NodeBB data backup done"

if [ ! -z "$isRunning" ] ; then
	echo -n "Restarting '${CONTAINER}' now... "
	podman start "$CONTAINER" >/dev/null && echo "done" || echo "failed"
fi