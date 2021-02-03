#!/bin/bash

# trigger pre start hook
${CONTAINER_REPO_DIR}.container/action_hooks/pre_start || exit 1

cd "${CONTAINER_REPO_DIR}nodebb"

exec &> >(tee -a "${CONTAINER_REPO_DIR}nodebb/logs/output.log")

# Installation should be done by now, make sure PORT is removed
# because NodeBB does not parse values from env, which means that
# "4567,4568" is kept as a string, instead of turned into an Array.
# Since env values override config.js values, loader.js sees a string
# and does not start cluster with multiple processes of NodeBB like it should.
unset PORT

# start process detached from script
# no daemon, so we can control when it stops
# no silent, so `podman logs` can be useful, but copy output to log file because NodeBB does not write there when not silent
daemon=false silent=false ./nodebb start &

# remember process ID
PID=$!

# store it for ./nodebb start|status|stop to work
echo -n $PID >pidfile

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

# cleanup pidfile
rm "${CONTAINER_REPO_DIR}nodebb/pidfile"
