#!/bin/bash

set -e

if [ ! -d "${CONTAINER_REPO_DIR}/nodebb/nodebb" ] ; then
	./.container/action_hooks/deploy || exit 1
	cd "${CONTAINER_REPO_DIR}nodebb"
else
	cd "${CONTAINER_REPO_DIR}nodebb"
	# rebuild frontend stuff
	${CONTAINER_REPO_DIR}nodebb/nodebb build || exit 1
fi

# start process detached from script
daemon=false silent=false ${CONTAINER_REPO_DIR}nodebb/nodebb start -l &

# remember process ID
PID=$!

# delegate kill signal
trap ${CONTAINER_REPO_DIR}'.container/action_hooks/pre_stop' INT TERM

# trigger post start hook
${CONTAINER_REPO_DIR}.container/action_hooks/post_start || exit 1

# attach script to process again; note: TERM signal unblocks this wait
wait $PID
trap - TERM INT

# wait for process to exit after signal delegation
wait $PID
EXIT_STATUS=$?