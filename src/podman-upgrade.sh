#!/bin/bash

if [ -z "$APP_NAME" ] ; then
    echo "ERROR: APP_NAME of new instance must be specified, so data from backup can be imported there" >&2
    return 1
fi

if ! podman pod exists ${APP_NAME} ; then
	echo "ERROR: pod '${APP_NAME}' does not exist" >&2
	return 1
fi

if [ -z "$NODEBB_VERSION" ] ; then
    echo "WARNING: NODEBB_VERSION was not specified, so upgrade will try latest released version" >&2
    NODEBB_VERSION="latest"
fi

if [ -z "$NODE_VERSION" ] ; then
    echo "WARNING: NODE_VERSION was not specified, so upgrade will use either version used in backup or minimal Node.js version required by selected NodeBB (whichever is higher)" >&2
fi

NOW=$(date -u +%Y-%m-%dT%H-%M-%S)
BACKUP_NAME="${APP_NAME}_${NOW}"

${__APP} stop $APP_NAME || return 1
${__APP} backup $APP_NAME /tmp "$BACKUP_NAME" || (${__APP} start $APP_NAME && exit 1) || return 1
# TODO: when podman supports renaming, create something like APP-upgrade first, test and if all ok, remove old and rename new pod and containers
${__APP} remove $APP_NAME || return 1
env NODE_VERSION="$NODE_VERSION" NODEBB_VERSION="$NODEBB_VERSION" ${__APP} restore $APP_NAME "/tmp/${BACKUP_NAME}" || ${__APP} restore $APP_NAME "/tmp/${BACKUP_NAME}" || return 1
rm -rf "/tmp/${BACKUP_NAME}">/dev/null || true
