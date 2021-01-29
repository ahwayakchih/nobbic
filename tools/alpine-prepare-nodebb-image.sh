#!/bin/sh

# WARNING: This script has to be run as root INSIDE Alpine-based container.
#          It's meant to copy files from /repo to /app/nodebb directory
#          and all the containerization stuff to /app

set -e

# Copy our stuff
cp -aT /containerizer/.container/. /app/.container
cp -aT /containerizer/logs/. /app/logs
cp -aT /containerizer/patches/. /app/patches

# Copy NodeBB stuff
cp -aT /repo/nodebb/. /app/nodebb

# Make sure we switched to correct repo version, just in case of some race condition between builders
env NODEBB_GIT="$NODEBB_GIT" NODEBB_VERSION="$NODEBB_VERSION" /containerizer/tools/alpine-get-nodebb-repo.sh

chown -R node:node /app

# `bash` for our scripts, `patch` for applying patches, `bind-tools` for dig (to check public IP)
# `jq`  and `git` should already be installed by alpine-get-nodebb-repo.sh script
apk add --no-cache\
	bash\
	patch\
	bind-tools