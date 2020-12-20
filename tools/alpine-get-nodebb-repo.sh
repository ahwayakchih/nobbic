#!/bin/sh

# WARNING: This script has to be run as root INSIDE Alpine-based container.
#          It's meant to build new image, based on one of official Node.js Alpine-based images.

set -e

NODEBB_GIT=${NODEBB_GIT:-https://github.com/NodeBB/NodeBB.git}
NODEBB_VERSION=${NODEBB_VERSION:-}

# Add `git` so we can clone repo and `jq` to extract required NODE_VERSION for specified NODEBB_VERSION
apk add --no-cache \
	git\
	jq

cd /app

# Clone git repository if it does not exist yet
if [ ! -d nodebb ] ; then
	git clone --recurse-submodules -j$(getconf _NPROCESSORS_ONLN || echo 1) "${NODEBB_GIT}" nodebb || return 1
elif [ ! -d nodebb/.git ] ; then
	echo "'nodebb' directory already exists, but does not look like a git repository." >&2
	echo "Please rename or remove it and try again." >&2
	return 1
else
	echo "'nodebb' directory already exists and looks like a git repo. resetting and updating." >&2
	# Reset repo, so we can checkout without any errors
	cd nodebb
	git fetch --tags
	git reset --hard
	git clean -xdf
	cd ..
fi

# Switch to specified version or latest release
cd nodebb
if [ "$NODEBB_VERSION" = "" ] ; then
	NODEBB_VERSION=${NODEBB_VERSION:-"tags/"$(git tag -l v* | cat | sort -V | tail -n 1)}
elif [ $(git tag -l v* | grep "v$NODEBB_VERSION") ] ; then
	NODEBB_VERSION="tags/v$NODEBB_VERSION"
fi

branchName=${NODEBB_VERSION/tags\//}
isBranch=$(git branch -l | grep "$branchName" || echo "")

if [ "$isBranch" != "" ] ; then
	git checkout "${branchName}" || exit 1
else
	git checkout ${NODEBB_VERSION} -b "$branchName" || exit 1
fi
# Extract currently checked out version number to a file for easy access
echo ${branchName/v/} > /app/NODEBB_VERSION

# Extract required nodejs version to a file for easy access
packageFile="/app/nodebb/package.json"
if [ ! -f "$packageFile" ] ; then
	packageFile="/app/nodebb/install/package.json"
fi
jq -r -c '.engines.node' "$packageFile" | tr -dc '0-9' > /app/NODE_VERSION
