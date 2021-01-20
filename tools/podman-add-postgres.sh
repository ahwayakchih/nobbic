#!/bin/bash

# WARNING: This script has to be run OUTSIDE container.
#          It's meant to add PostgreSQL to the specified pod.

set -e
__DIRNAME=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
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
password=`tr -cd '[:alnum:]' < /dev/urandom | fold -w16 | head -n1 | fold -w4 | paste -sd\- -`

	# Specyfing custom user name seem to prevent us from accessing db:
	# "NodeBB could not connect to your PostgreSQL database. PostgreSQL returned the following error: role "custom_user" does not exist"
	# -e POSTGRES_USER="$POD"\
podman run -d --pod "$POD" --name "$CONTAINER" \
	-e POSTGRES_PASSWORD="$password"\
	-e POSTGRES_DB="$POD"\
	-e CONTAINER_DATA_DIR="$dataDir"\
	"$POSTGRES_IMAGE" >/dev/null || exit 1

POSTGRES_PORT=5432

# Import from backup, if specified
if [ ! -z "$RESTORE_FROM" ] && [ -f "${RESTORE_FROM}/postgres.txt" ] ; then
	podman run --rm --pod "$POD" -v "${__APPDIR}/.container/tools:/tools:ro" docker.io/alpine /tools/wait-for.sh "localhost:${POSTGRES_PORT}" -t 20 >&2 || exit 1
	podman exec -i -u postgres "$CONTAINER" psql -U postgres -d $POD < "${RESTORE_FROM}/postgres.txt" >&2 || exit 1
fi

echo '-e CONTAINER_POSTGRES_HOST=localhost -e CONTAINER_POSTGRES_PORT='$POSTGRES_PORT' -e CONTAINER_POSTGRES_PASSWORD='$password\
	'-e CONTAINER_POSTGRES_USER=postgres -e CONTAINER_POSTGRES_DB='$POD
