#!/bin/sh

# WARNING: This script has to be run as root INSIDE Alpine-based container.
#          It's meant to copy files all the containerization stuff to /app.

set -e

# Copy our stuff
cp -aT /mnt/.container/. /app/.container
cp -aT /mnt/logs/. /app/logs
cp -aT /mnt/patches/. /app/patches

# Make sure `node` user owns newly copied files and NodeBB files mounted under /app/nodebb
chown -R node:node /app
