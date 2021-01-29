#!/bin/bash

# WARNING: This script has to be run OUTSIDE container.
#          It's meant to build new image, based on one of official Node.js Alpine-based images.

__DIRNAME=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
source ${__DIRNAME}/common.sh

IMAGE_NAME="nodebb-repo"
BUILDER_NAME="build-${IMAGE_NAME}"

if ! podman image exists nodebb-repo ; then
	podman run --replace --name "$BUILDER_NAME" docker.io/alpine apk add --no-cache git jq\
		&& podman cp ${__DIRNAME}/alpine-get-nodebb-repo.sh "${BUILDER_NAME}:/usr/local/bin/alpine-get-nodebb-repo.sh"\
    	&& podman commit -c CMD=alpine-get-nodebb-repo.sh -c WORKDIR=/app "$BUILDER_NAME" $IMAGE_NAME:latest\
	    && podman rm "$BUILDER_NAME"
fi
