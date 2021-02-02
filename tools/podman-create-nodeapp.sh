#!/bin/bash

# WARNING: This script has to be run OUTSIDE container.
#          It's meant to build new image, based on one of official Node.js Alpine-based images.

__DIRNAME=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
source ${__DIRNAME}/common.sh

if [ -z "$NODE_VERSION" ] ; then
    echo "ERROR: NODE_VERSION not specified" >&2
    exit 1
fi

if [ -z "$APP_NAME" ] ; then
    APP_NAME="nodeapp"
    echo "WARNING: APP_NAME not specified, default '$APP_NAME' will be used" >&2
fi

if podman image exists ${APP_NAME}:${NODE_VERSION} ; then
	echo "Skipping building ${APP_NAME}:${NODE_VERSION} because it already exists" >&2
	exit 0
fi

echo "Building Node.js image for v$NODE_VERSION"
NODE_IMAGE=${FROM_IMAGE:-"docker.io/node:%NODE_VERSION%-alpine"}
NODE_IMAGE=${NODE_IMAGE/\%NODE_VERSION\%/$NODE_VERSION}
echo "Using $NODE_IMAGE as a base for ${APP_NAME}:${NODE_VERSION}"

podman run --replace --name build-${APP_NAME} -v ${__DIRNAME}:/tools:ro "$NODE_IMAGE" /bin/sh /tools/alpine-reconfigure-node.sh\
    && podman commit -c CMD=/bin/sh -c USER=node -c WORKDIR=/app -c ENV=ENV=/etc/profile build-${APP_NAME} ${APP_NAME}:${NODE_VERSION}\
    && podman rm build-${APP_NAME}

INSTALLED_NODE_VERSION=$(podman run --rm ${APP_NAME}:${NODE_VERSION} node --version)
if [ "v${NODE_VERSION}" != "$INSTALLED_NODE_VERSION" ] ; then
	podman tag ${APP_NAME}:${NODE_VERSION} ${APP_NAME}:${INSTALLED_NODE_VERSION/v/}
fi
