#!/bin/bash

# WARNING: This script has to be run OUTSIDE container.
#          It's meant to build new image, based on one of official Node.js Alpine-based images.

set -e
__DIRNAME=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

APP_NAME="$APP_NAME"
if [ -z "$APP_NAME" ] ; then
    echo "WARNING: APP_NAME not specified, default 'nodebb' will be used" >&2
    APP_NAME="nodebb"
fi

NODEBB_REPO_VOLUME="${APP_NAME}-nodebb-repo"

# Clone NodeBB repo to separate volume, so we don't have to do full clone again next time
# and so we can extract which NODE_VERSION selected NODEBB_VERSION depends on.
echo "Preparing NodeBB repo in volume $NODEBB_REPO_VOLUME"
podman run --replace --rm --name ${APP_NAME}-nodebb-downloader\
    -e NODEBB_GIT=$NODEBB_GIT\
    -e NODEBB_VERSION="$NODEBB_VERSION"\
    -v ${__DIRNAME}:/tools:ro\
    -v $NODEBB_REPO_VOLUME:/app\
    docker.io/alpine /bin/sh /tools/alpine-get-nodebb-repo.sh

NODEBB_VERSION="$NODEBB_VERSION"
if [ -z "$NODEBB_VERSION" ] || [ "$NODEBB_VERSION" = "latest" ] ; then
    NODEBB_VERSION=$(podman run --rm -v $NODEBB_REPO_VOLUME:/app:ro docker.io/alpine cat /app/NODEBB_VERSION)
    if [ -z "$NODEBB_VERSION" ] ; then
        echo "ERROR: could not determine current NODEBB_VERSION" >&2
        exit 1
    fi
fi

# Make sure minimal required Node.js version is matched
REQUIRED_NODE_VERSION=$(podman run --rm -v $NODEBB_REPO_VOLUME:/app:ro docker.io/alpine cat /app/NODE_VERSION)
if [ -z "$NODE_VERSION" ] ; then
    NODE_VERSION=$REQUIRED_NODE_VERSION
else
    HIGHER_NODE_VERSION=$(echo -e "${REQUIRED_NODE_VERSION}\n${NODE_VERSION}" | sort -V | tail -n 1)
    if [ "$NODE_VERSION" != "$HIGHER_NODE_VERSION" ] ; then
        NODE_VERSION=$REQUIRED_NODE_VERSION
    fi
fi

if [ -z "$NODE_VERSION" ] ; then
    echo "ERROR: could not determine required NODE_VERSION" >&2
    exit 1
fi

NODEBB_GIT="$NODEBB_GIT"
if [ -z "$NODEBB_GIT" ] ; then
    NODEBB_GIT=$(podman run --rm -v $NODEBB_REPO_VOLUME:/app:ro docker.io/alpine cat /app/NODEBB_GIT)
    if [ -z "$NODEBB_GIT" ] ; then
        echo "ERROR: could not determine current NODEBB_GIT" >&2
        exit 1
    fi
fi

echo "Preparing Node.js v$NODE_VERSION image for NodeBB $NODEBB_VERSION"
NODE_VERSION=$NODE_VERSION APP_NAME=${APP_NAME}-node ./tools/podman-create-nodeapp.sh

echo "Preparing NodeBB $NODEBB_VERSION image for $APP_NAME"
IMAGE_NAME=${APP_NAME}-nodebb:${NODE_VERSION}-${NODEBB_VERSION}
if podman image exists $IMAGE_NAME ; then
    echo "Skipping building image which already exists"
    # TODO: support some kind of "force-rebuild" switch?
else
    podman run --replace --name ${APP_NAME}-nodebb-build\
        -e NODEBB_GIT=$NODEBB_GIT\
        -e NODEBB_VERSION=$NODEBB_VERSION\
        -u root\
        -v ${__DIRNAME}/../:/containerizer:ro\
        -v $NODEBB_REPO_VOLUME:/repo:ro\
        ${APP_NAME}-node:${NODE_VERSION} /bin/sh /containerizer/tools/alpine-prepare-nodebb-image.sh
    podman commit\
        -c "ENV=CONTAINER_APP_NAME=${APP_NAME}"\
        -c "ENV=NODEBB_GIT=${NODEBB_GIT}"\
        -c "ENV=NODEBB_VERSION=${NODEBB_VERSION}"\
        -c "ENV=NODE_ENV=${NODE_ENV:-production}"\
        -c "ENV=CONTAINER_REPO_DIR=/app/"\
        -c "ENV=CONTAINER_DATA_DIR=/data/"\
        -c "VOLUME /data"\
        -c 'USER node'\
        -c 'WORKDIR /app'\
        -c 'CMD ["/bin/bash", "-l", "./.container/entrypoint.sh"]'\
        ${APP_NAME}-nodebb-build $IMAGE_NAME
    podman rm ${APP_NAME}-nodebb-build
fi

echo "Image $IMAGE_NAME is ready"
if [ ! -z "$IMAGE_NAME_FILE" ] ; then
    echo -n "Writing Nodebb container image name to ${IMAGE_NAME_FILE}... "
    echo "$IMAGE_NAME" > $IMAGE_NAME_FILE
    echo "done!"
fi
