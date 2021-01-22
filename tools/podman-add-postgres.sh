#!/bin/bash

# WARNING: This script has to be run OUTSIDE container.
#          It's meant to add PostgreSQL to the specified pod.

__DIRNAME=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
source ${__DIRNAME}/common.sh
__APPDIR=$(dirname $__DIRNAME)

POD="$POD"
if [ -z "$POD" ] ; then
	echo "ERROR: POD name must be specified to add PostgreSQL to it" >&2
	exit 1
fi

if ! podman pod exists ${POD} ; then
	echo "ERROR: could not find pod '${POD}'" >&2
	exit 1
fi

CONTAINER="$CONTAINER"
if [ -z "$CONTAINER" ] ; then
	CONTAINER="${POD}-postgres"
fi

POSTGRES_IMAGE=${FROM_IMAGE:-docker.io/postgres:alpine}

# Make sure image is available before we inspect it
if ! podman image exists "$POSTGRES_IMAGE" >/dev/null ; then
	if ! podman pull "$POSTGRES_IMAGE" >/dev/null ; then
		echo "ERROR: could not find '$POSTGRES_IMAGE'" >&2
		exit 1
	fi
fi

# Get PGDATA from env used by default by official PostgreSQL images.
# We'll set CONTAINER_DATA_DIR to the same value, so backups know what to archive.
dataDir=$(podman inspect "$POSTGRES_IMAGE" --format='{{range .Config.Env}}{{.}}\n{{end}}'| grep PGDATA | cut -d= -f2)

# Generate random password for database access
# Ignore exit code 141 which hapens in case of writing to pipe that was closed, which is our case (read urandom until enough data is gathered),
# by using trick from https://stackoverflow.com/a/33026977/6352710, i.e., `|| test $? -eq 141` part.
password=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w16 | head -n1 | fold -w4 | paste -sd\- - || test $? -eq 141)

	# Specyfing custom user name seem to prevent us from accessing db:
	# "NodeBB could not connect to your PostgreSQL database. PostgreSQL returned the following error: role "custom_user" does not exist"
	# -e POSTGRES_USER="$POD"\
podman create --pod "$POD" --name "$CONTAINER" \
	-e POSTGRES_PASSWORD="$password"\
	-e POSTGRES_DB="$POD"\
	-e CONTAINER_DATA_DIR="$dataDir"\
	"$POSTGRES_IMAGE" >/dev/null || exit 1

POSTGRES_PORT=5432

# Import from backup, if specified
if [ ! -z "$RESTORE_FROM" ] && [ -f "${RESTORE_FROM}/postgres.txt" ] ; then
	podman cp "${RESTORE_FROM}/postgres.txt" ${CONTAINER}:/docker-entrypoint-initdb.d/restore-${POD}.sql
fi

echo '-e CONTAINER_POSTGRES_HOST='$POD' -e CONTAINER_POSTGRES_PORT='$POSTGRES_PORT' -e CONTAINER_POSTGRES_PASSWORD='$password\
	'-e CONTAINER_POSTGRES_USER=postgres -e CONTAINER_POSTGRES_DB='$POD
