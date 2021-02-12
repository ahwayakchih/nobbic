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
    export NODEBB_VERSION="latest"
    echo "WARNING: NODEBB_VERSION was not specified, so upgrade will try ${NODEBB_VERSION} version" >&2
fi

if [ -z "$NODE_VERSION" ] ; then
    echo "WARNING: NODE_VERSION was not specified, so upgrade will use either version used currently or minimal Node.js version required by selected NodeBB (whichever is higher)" >&2
fi

NOW=$(date -u +%Y-%m-%dT%H-%M-%S)
export BACKUP_NAME=${BACKUP_NAME:-${APP_NAME}_${NOW}_before_upgrade}

env ${__APP} stop $APP_NAME || return 1
env ${__APP} backup $APP_NAME || (${__APP} start $APP_NAME && exit 1) || return 1
# TODO: when podman supports renaming pods, restore to something like "APP_NAME-upgrade" first, test and if all ok, remove old and rename new pod and containers
${__APP} remove $APP_NAME || return 1
env ${__APP} restore $APP_NAME || ${__APP} restore $APP_NAME || return 1
