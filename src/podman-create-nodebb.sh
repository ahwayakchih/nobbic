#!/bin/bash

if [ -z "$APP_NAME" ] ; then
    export APP_NAME="nodebb"
    echo "WARNING: APP_NAME not specified, default '$APP_NAME' will be used" >&2
fi

NODEBB_REPO_VOLUME=${NODEBB_REPO_VOLUME:-nodebb-repo}
NODEBB_REPO_DOWNLOADER="${NODEBB_REPO_VOLUME}-downloader"

# Clone NodeBB repo to separate volume, so we don't have to do full clone again next time
# and so we can extract which NODE_VERSION selected NODEBB_VERSION depends on.
inline podman-create-nodebb-repo.sh
# We split NodeBB directories into 3 volumes, so it's easier to share selected parts between containers
# Also, ${APP_NAME}-nodebbb* volumes will need `chown` run on them, once node.js image is ready
# (repo container is pure Alpine, so no "node" user yet).
podman run --replace -it --rm --name nodebb-downloader\
    -e NODEBB_GIT=$NODEBB_GIT\
    -e NODEBB_VERSION="$NODEBB_VERSION"\
    -v $NODEBB_REPO_VOLUME:/app\
    -v ${APP_NAME}-nodebb:/target:z\
    -v ${APP_NAME}-nodebb-build:/target/build:z\
    -v ${APP_NAME}-nodebb-public:/target/public:z\
    -e CONTAINER_INSTALL_DIR=/target\
    ${NODEBB_REPO_IMAGE}

if [ -z "$NODEBB_VERSION" ] || [ "$NODEBB_VERSION" = "latest" ] ; then
    NODEBB_VERSION=$(podman run --rm -v $NODEBB_REPO_VOLUME:/app:ro docker.io/alpine cat /app/NODEBB_VERSION)
    if [ -z "$NODEBB_VERSION" ] ; then
        echo "ERROR: could not determine current NODEBB_VERSION" >&2
        return 1
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
    return 1
fi

if [ -z "$NODEBB_GIT" ] ; then
    NODEBB_GIT=$(podman run --rm -v $NODEBB_REPO_VOLUME:/app:ro docker.io/alpine cat /app/NODEBB_GIT)
    if [ -z "$NODEBB_GIT" ] ; then
        echo "ERROR: could not determine current NODEBB_GIT" >&2
        return 1
    fi
fi

echo "Preparing Node.js v$NODE_VERSION image for NodeBB $NODEBB_VERSION"
export NODEBB_NODE_IMAGE="nodebb-node"
inline podman-create-nodebb-node.sh

INSTALLED_NODE_VERSION=$(podman run --rm ${NODEBB_NODE_IMAGE}:${NODE_VERSION} node --version)
NODE_VERSION=${INSTALLED_NODE_VERSION/v/}

echo "Preparing NodeBB $NODEBB_VERSION (using Node.js v$NODE_VERSION) image for $APP_NAME"
export NODEBB_IMAGE=nodebb:${NODE_VERSION}-${NODEBB_VERSION}
if podman image exists $NODEBB_IMAGE ; then
    echo "Skipping building image which already exists"
    # Just make sure NodeBB volumes are owned by "node" user
    podman run --rm -it --replace --name prepare-nodebb\
        -u root\
        -v ${APP_NAME}-nodebb:/app/node:z\
        -v ${APP_NAME}-nodebb-build:/app/node/build:z\
        -v ${APP_NAME}-nodebb-public:/app/node/public:z\
         $NODEBB_IMAGE /bin/sh -c 'chown -R node:node /app'
    # TODO: support some kind of "force-rebuild" switch?
else
    podman run --replace --name build-nodebb\
        -e NODEBB_GIT=$NODEBB_GIT\
        -e NODEBB_VERSION=$NODEBB_VERSION\
        -u root\
        -v ${APP_NAME}-nodebb:/app/node:z\
        -v ${APP_NAME}-nodebb-build:/app/node/build:z\
        -v ${APP_NAME}-nodebb-public:/app/node/public:z\
        -v ${__DIRNAME}:/mnt:ro\
        ${NODEBB_NODE_IMAGE}:${NODE_VERSION} /bin/sh /mnt/tools/alpine-prepare-nodebb-image.sh
    podman commit\
        -c "ENV=NODEBB_GIT=${NODEBB_GIT}"\
        -c "ENV=NODEBB_VERSION=${NODEBB_VERSION}"\
        -c "ENV=NODE_ENV=${NODE_ENV:-production}"\
        -c "ENV=CONTAINER_REPO_DIR=/app/"\
        -c 'USER node'\
        -c 'WORKDIR /app'\
        -c 'CMD ["/bin/bash", "-l", "./.container/entrypoint.sh"]'\
        build-nodebb $NODEBB_IMAGE
    podman rm build-nodebb
fi

export PODMAN_CREATE_ARGS_NODEBB="${PODMAN_CREATE_ARGS_NODEBB}\
    -v ${APP_NAME}-nodebb:/app/nodebb:z\
    -v ${APP_NAME}-nodebb-public:/app/nodebb/public:z\
    -v ${APP_NAME}-nodebb-build:/app/nodebb/build:z"
