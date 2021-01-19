#!/bin/sh

# WARNING: This script has to be run OUTSIDE container.
#          It's meant to restore containers' data from backup.

set -e
__DIRNAME=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
__APP=$(dirname "$__DIRNAME")"/app"

APP_NAME="$APP_NAME"
if [ -z "$APP_NAME" ] ; then
    echo "ERROR: APP_NAME of new instance must be specified, so data from backup can be imported there" >&2
    exit 1
fi

BACKUPS_DIR="$BACKUPS_DIR"
if [ -z "$BACKUPS_DIR" ] ; then
	BACKUPS_DIR=$(pwd)"/backups"
	echo "WARNING: no BACKUPS_DIR specified, defaulting to '$BACKUPS_DIR'" >&2
elif [ -z "$BACKUP_NAME" ] && [ -f "$BACKUPS_DIR/nodebb.env" ] ; then
	BACKUP_NAME=$(basename "$BACKUPS_DIR")
	BACKUPS_DIR=$(dirname "$BACKUPS_DIR")
fi

BACKUP_NAME="$BACKUP_NAME"
if [ -z "$BACKUP_NAME" ] ; then
	BACKUP_NAME=$(ls "$BACKUPS_DIR" | grep "^$APP_NAME" | sort -n | tail -n 1)
	if [ -z "$BACKUP_NAME" ] ; then
		echo "ERROR: could not find backup of '$APP_NAME', if you are trying to import data to a new app, specify full path to selected backup" >&2
		exit 1
	fi
	echo "WARNING: no BACKUP_NAME specified, defaulting to latest, i.e., '$BACKUP_NAME'" >&2
else
	if [ "$BACKUP_NAME" != $(basename "$BACKUP_NAME") ] ; then
		BACKUPS_DIR=$(dirname $(readlink -f "$BACKUP_NAME"))
		BACKUP_NAME=$(basename "$BACKUP_NAME")
	fi
fi

echo "Restoring $APP_NAME container data from ${BACKUPS_DIR}/${BACKUP_NAME} backup"
fromName="${BACKUPS_DIR}/${BACKUP_NAME}"
if [ ! -d "$fromName" ] ; then
	echo "ERROR: $fromName does not exist" >&2
	exit 1
else
	fromName=$(readlink -f "$fromName")
fi

if podman pod exists ${APP_NAME} ; then
	echo "ERROR: pod '${APP_NAME}' already exists, remove it before trying to retore it" >&2
	exit 1
fi

if [ ! -f "${fromName}/nodebb.env" ] ; then
	echo "ERROR: could not find '${fromName}/nodebb.env' to restore from" >&2
	exit 1
fi

# Allow to enforce version numbers
FORCE_NODE_VERSION=$NODE_VERSION
FORCE_NODEBB_VERSION=$NODEBB_VERSION

# Get most of the setup variables from backed up NodeBB's environment
source "${fromName}/nodebb.env"

# Prepeare base environment variables
cmd="NODE_VERSION=${FORCE_NODE_VERSION:-$NODE_VERSION}\
	NODEBB_VERSION=${FORCE_NODEBB_VERSION:-$NODEBB_VERSION}\
	NODEBB_GIT='${NODEBB_GIT}'\
	CONTAINER_NODEJS_PORT=${CONTAINER_NODEJS_PORT}\
	CONTAINER_WEBSOCKET_PORT=${CONTAINER_WEBSOCKET_PORT}\
	CONTAINER_APP_DNS_ALIAS=${CONTAINER_APP_DNS_ALIAS}\
	${__APP} start ${APP_NAME}
	"
# Check which database(s) to use
if [ ! -z "$CONTAINER_POSTGRES_PORT" ] && [ -f "${fromName}/container-postgres.json" ] ; then
	# TODO: get container image name and pass it instead of "1"
	cmd="APP_ADD_POSTGRES=1 ${cmd}"
elif [ ! -z "$CONTAINER_MONGODB_PORT" ] && [ -f "${fromName}/container-mongodb.json" ] ; then
	# TODO: get container image name and pass it instead of "1"
	cmd="APP_ADD_MONGODB=1 ${cmd}"
fi

if [ ! -z "$CONTAINER_REDIS_PORT" ] && [ -f "${fromName}/container-redis.json" ] ; then
	# TODO: get container image name and pass it instead of "1"
	cmd="APP_ADD_REDIS=1 ${cmd}"
fi

cmd="RESTORE_FROM='${fromName}' ${cmd}"

eval $cmd
