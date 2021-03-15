#!/bin/bash

export NODEBB_TOOLBOX_IMAGE="nodebb-toolbox"

if ! podman image exists ${NODEBB_TOOLBOX_IMAGE} &>/dev/null ; then
	local BUILDER_NAME="build-${NODEBB_TOOLBOX_IMAGE}"

	# `jq` to manipulate JSON files in a bit more sane way than in pure bash,
	# `git` to get NodeBB repo,
	# `curl` to test web server connections,
	# `openssl` to test SSL connections,
	# `bind-tools` for dig (to check public IP).
	podman run --replace --name "$BUILDER_NAME" docker.io/alpine apk add --no-cache jq git curl openssl bind-tools\
		&& podman cp ${__TOOLS}/alpine-get-nodebb-repo.sh "${BUILDER_NAME}:/usr/local/bin/alpine-get-nodebb-repo.sh"\
		&& podman cp ${__TOOLS}/alpine-run-acme-server.sh "${BUILDER_NAME}:/usr/local/bin/alpine-run-acme-server.sh"\
		&& podman cp ${__TOOLS}/acme-server.sh "${BUILDER_NAME}:/usr/local/bin/acme-server.sh"\
    	&& podman commit -c CMD=alpine-get-nodebb-repo.sh -c WORKDIR=/app -c "LABEL ${__LABEL}=${__VERSION}" "$BUILDER_NAME" $NODEBB_TOOLBOX_IMAGE:latest\
	    && podman rm "$BUILDER_NAME"
fi
