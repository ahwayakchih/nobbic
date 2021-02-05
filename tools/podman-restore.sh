#!/bin/bash

# WARNING: This script has to be run OUTSIDE container.
#          It's meant to restore containers' data from backup.

__DIRNAME=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
source ${__DIRNAME}/common.sh
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

# Prepeare base environment variables
# Get most of the setup variables from backed up NodeBB's environment,
# while trying to keep our env safe.
# TODO: drop support for CONTAINER_NODEJS_PORT and CONTAINER_APP_DNS_ALIAS.
cmd=$(env -i $(xargs -a "${fromName}/nodebb.env") \
		FORCE_NODE_VERSION="$FORCE_NODE_VERSION" \
		FORCE_NODEBB_VERSION="$FORCE_NODEBB_VERSION" \
		FORCE_NODEBB_CLUSTER="${APP_USE_CLUSTER:-}" \
		/bin/sh -c 'echo NODE_VERSION="${FORCE_NODE_VERSION:-$NODE_VERSION}"\
			NODEBB_VERSION="${FORCE_NODEBB_VERSION:-$NODEBB_VERSION}"\
			NODEBB_GIT="${NODEBB_GIT}"\
			APP_USE_PORT="${APP_USE_PORT:-$CONTAINER_NODEJS_PORT}"\
			APP_USE_FQDN="${APP_USE_FQDN:-$CONTAINER_APP_DNS_ALIAS}"\
			APP_USE_CLUSTER=${FORCE_NODEBB_CLUSTER:-$(( $(echo $PORT | tr -cd , | wc -c) + 1))}\
		')

get_image_name () {
	cat "$1" 2>/dev/null | grep ImageName | sed 's/^.*ImageName.*:\s*"//' | sed 's/".*$//' || echo "1"
}

# Check which database(s) to use
if [ -f "${fromName}/container-postgres.json" ] ; then
	oldImage=$(get_image_name "${fromName}/container-postgres.json")
	cmd="APP_ADD_POSTGRES='${APP_ADD_POSTGRES:-$oldImage}' ${cmd}"
elif [ -f "${fromName}/container-mongodb.json" ] ; then
	oldImage=$(get_image_name "${fromName}/container-mongodb.json")
	cmd="APP_ADD_MONGODB='${APP_ADD_MONGODB:-$oldImage}' ${cmd}"
fi

if [ -n "$APP_ADD_REDIS" ] || [ -f "${fromName}/container-redis.json" ] ; then
	oldImage=$(get_image_name "${fromName}/container-redis.json")
	cmd="APP_ADD_REDIS='${APP_ADD_REDIS:-$oldImage}' ${cmd}"
fi

if [ -n "$APP_ADD_NPM" ] || [ -f "${fromName}/container-npm.json" ] ; then
	oldImage=$(get_image_name "${fromName}/container-npm.json")
	cmd="APP_ADD_NPM='${APP_ADD_NPM:-$oldImage}' ${cmd}"
fi

if [ -n "$APP_ADD_NGINX" ] || [ -f "${fromName}/container-nginx.json" ] ; then
	oldImage=$(get_image_name "${fromName}/container-nginx.json")
	cmd="APP_ADD_NGINX='${APP_ADD_NGINX:-$oldImage}' ${cmd}"
fi

cmd="RESTORE_FROM='${fromName}'	${cmd}"

# Alpine/Busybox's env does not support "-S" option (to split single string full of variable declarations).
# That's why we need to echo them through xargs, to call env with args separated properly and in correct order.
env $(echo "$cmd" | xargs) ${__APP} start ${APP_NAME}
