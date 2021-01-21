#!/bin/bash

# WARNING: This script has to be run OUTSIDE container.
#          It's meant to build new image, based on one of official Node.js Alpine-based images.

__DIRNAME=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
source ${__DIRNAME}/common.sh

if [ -z "$NODE_VERSION" ] ; then
    echo "ERROR: NODE_VERSION not specified" >&2
    exit 1
fi

APP_NAME="$APP_NAME"
if [ -z "$APP_NAME" ] ; then
    echo "WARNING: APP_NAME not specified, default 'nodeapp' will be used" >&2
    APP_NAME="nodeapp"
fi

if podman image exists ${APP_NAME}:${NODE_VERSION} ; then
	echo "Skipping building ${APP_NAME}:${NODE_VERSION} because it already exists"
	exit 0
fi

podman run --replace --name build-${APP_NAME} -v ${__DIRNAME}:/tools:ro docker.io/node:${NODE_VERSION}-alpine /bin/sh /tools/alpine-reconfigure-node.sh\
    && podman commit -c CMD=/bin/sh -c USER=node -c WORKDIR=/app build-${APP_NAME} ${APP_NAME}:${NODE_VERSION}\
    && podman rm build-${APP_NAME}

INSTALLED_NODE_VERSION=$(podman run --rm ${APP_NAME}:${NODE_VERSION} node --version)
if [ "v${NODE_VERSION}" != "$INSTALLED_NODE_VERSION" ] ; then
	podman tag ${APP_NAME}:${NODE_VERSION} ${APP_NAME}:${INSTALLED_NODE_VERSION/v/}
fi
