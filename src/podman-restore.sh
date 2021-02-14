#!/bin/bash

if [ -z "$APP_NAME" ] ; then
    echo "ERROR: APP_NAME of new instance must be specified, so data from backup can be imported there" >&2
    return 1
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
		return 1
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
	return 1
else
	fromName=$(readlink -f "$fromName")
fi

# This check is here, not at the beginning, because we do not want user to remove pod
# if backup does not exist, or is invalid for some reason
if podman pod exists ${APP_NAME} &>/dev/null ; then
	echo "ERROR: pod '${APP_NAME}' already exists, remove it before trying to retore it" >&2
	return 1
fi

if [ ! -f "${fromName}/nodebb.env" ] ; then
	echo "ERROR: could not find '${fromName}/nodebb.env' to restore from" >&2
	return 1
fi

# Import POD env first, so we can keep whatever values user enforced before
import "${fromName}/pod.env"

# Import NodeBB env next, but only values that are auto-created and required for
# setting up correct versions.
# Things like CONTAINER_ENV_* are not, and they often are modified by *-add-*scripts,
# or they were already declared in pod.env.
import "${fromName}/nodebb.env" "^(NODE(BB)?_|APP_|PORT)"

# Backward compatibility with old backups
# TODO: drop support for CONTAINER_NODEJS_PORT and CONTAINER_APP_DNS_ALIAS.
export APP_USE_PORT=${APP_USE_PORT:-$CONTAINER_NODEJS_PORT}
export APP_USE_FQDN=${APP_USE_FQDN:-$CONTAINER_APP_DNS_ALIAS}

# APP_USE_CLUSTER is not saved, so calculate it from PORT
export APP_USE_CLUSTER=${APP_USE_CLUSTER:-$(( $(echo $PORT | tr -cd , | wc -c) + 1))}

# Check which database(s) to use
if [ -f "${fromName}/container-postgres.json" ] ; then
	oldImage=$(get_image_name_from_json "${fromName}/container-postgres.json")
	export APP_ADD_POSTGRES=${APP_ADD_POSTGRES:-$oldImage}
elif [ -f "${fromName}/container-mongodb.json" ] ; then
	oldImage=$(get_image_name_from_json "${fromName}/container-mongodb.json")
	export APP_ADD_MONGODB=${APP_ADD_MONGODB:-$oldImage}
fi

if [ -n "$APP_ADD_REDIS" ] || [ -f "${fromName}/container-redis.json" ] ; then
	oldImage=$(get_image_name_from_json "${fromName}/container-redis.json")
	export APP_ADD_REDIS=${APP_ADD_REDIS:-$oldImage}
fi

if [ -n "$APP_ADD_NPM" ] || [ -f "${fromName}/container-npm.json" ] ; then
	oldImage=$(get_image_name_from_json "${fromName}/container-npm.json")
	export APP_ADD_NPM=${APP_ADD_NPM:-$oldImage}
fi

if [ -n "$APP_ADD_NGINX" ] || [ -f "${fromName}/container-nginx.json" ] ; then
	oldImage=$(get_image_name_from_json "${fromName}/container-nginx.json")
	export APP_ADD_NGINX=${APP_ADD_NGINX:-$oldImage}
fi

export RESTORE_FROM=${fromName}

exec ${__APP} start ${APP_NAME}
