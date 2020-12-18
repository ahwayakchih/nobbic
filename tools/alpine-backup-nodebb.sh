#!/bin/sh

# WARNING: This script has to be run INSIDE container.
#          It's meant to create backup of NodeBBs file data.

set -e

if [ -z "$CONTAINER_DATA_DIR" ] ; then
	echo "ERROR: no CONTAINER_DATA_DIR specified when trying to backup NodeBB data" >&2
	exit 1
fi

if [ -z "$BACKUP_TO_FILE" ] ; then
	echo "ERROR: no BACKUP_TO_FILE file path specified when trying to backup NodeBB data" >&2
	exit 1
fi

tar cvf "${BACKUP_TO_FILE}.tar" "$CONTAINER_DATA_DIR"
