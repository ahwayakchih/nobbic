#!/bin/bash

# WARNING: This script has to be run INSIDE MongoDB container.
#          It's meant to restore data from backup.

set -e

if [ -z "$MONGO_INITDB_DATABASE" ] ; then
	exit 0
fi

ARCHIVE="/docker-entrypoint-initdb.d/restore-${MONGO_INITDB_DATABASE}.archive"
if [ ! -f "$ARCHIVE" ] ; then
	exit 0
fi

echo "Restoring data from $ARCHIVE"
mongorestore -d "$MONGO_INITDB_DATABASE" --archive="$ARCHIVE"
