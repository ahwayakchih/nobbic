#!/bin/bash

export NODEBB_REPO_IMAGE="nodebb-repo"
BUILDER_NAME="build-${NODEBB_REPO_IMAGE}"

if ! podman image exists nodebb-repo &>/dev/null ; then
	podman run --replace --name "$BUILDER_NAME" docker.io/alpine apk add --no-cache git jq\
		&& podman cp ${__TOOLS}/alpine-get-nodebb-repo.sh "${BUILDER_NAME}:/usr/local/bin/alpine-get-nodebb-repo.sh"\
    	&& podman commit -c CMD=alpine-get-nodebb-repo.sh -c WORKDIR=/app "$BUILDER_NAME" $NODEBB_REPO_IMAGE:latest\
	    && podman rm "$BUILDER_NAME"
fi
