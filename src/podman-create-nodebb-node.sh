#!/bin/bash

if [ -z "$NODE_VERSION" ] ; then
    echo "ERROR: NODE_VERSION not specified" >&2
    return 1
fi

if [ -z "$NODEBB_NODE_IMAGE" ] ; then
    export NODEBB_NODE_IMAGE="nodebb-node"
    echo "WARNING: NODEBB_NODE_IMAGE not specified, default '$NODEBB_NODE_IMAGE' will be used" >&2
fi

if podman image exists ${NODEBB_NODE_IMAGE}:${NODE_VERSION} ; then
	echo "Skipping building ${NODEBB_NODE_IMAGE}:${NODE_VERSION} because it already exists" >&2
	return 0
fi

echo "Building Node.js image for v$NODE_VERSION"
NODE_IMAGE=${FROM_IMAGE:-"docker.io/node:%NODE_VERSION%-alpine"}
NODE_IMAGE=${NODE_IMAGE/\%NODE_VERSION\%/$NODE_VERSION}
echo "Using $NODE_IMAGE as a base for ${NODEBB_NODE_IMAGE}:${NODE_VERSION}"

podman run --replace --name build-${NODEBB_NODE_IMAGE} -v ${__TOOLS}/alpine-reconfigure-node.sh:/usr/local/bin/alpine-reconfigure-node.sh:ro "$NODE_IMAGE" alpine-reconfigure-node.sh\
    && podman commit -c CMD=/bin/sh -c USER=node -c WORKDIR=/app -c ENV=ENV=/etc/profile build-${NODEBB_NODE_IMAGE} ${NODEBB_NODE_IMAGE}:${NODE_VERSION}\
    && podman rm build-${NODEBB_NODE_IMAGE}

INSTALLED_NODE_VERSION=$(podman run --rm ${NODEBB_NODE_IMAGE}:${NODE_VERSION} node --version)
if [ "v${NODE_VERSION}" != "$INSTALLED_NODE_VERSION" ] ; then
	podman tag ${NODEBB_NODE_IMAGE}:${NODE_VERSION} ${NODEBB_NODE_IMAGE}:${INSTALLED_NODE_VERSION/v/}
fi
