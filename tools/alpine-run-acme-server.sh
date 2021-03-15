#!/bin/sh

# WARNING: This script has to be run INSIDE container.
#          It's meant to start basic server that responds with the same content to every request.

set -e

RESPONSE_CONTENT=${1:-}
SERVER_PID=

if [ -z "$RESPONSE_CONTENT" ] ; then
	echo "Usage: alpine-run-test-server.sh TEXT_CONTENT"
	echo ""
	echo "Example:"
	echo "  alpine-run-test-server.sh 'Hello world!'"
	exit 0
fi

trap '[ -n "$SERVER_PID" ] && kill -9 "$SERVER_PID" && exit 0' INT TERM

debug() {
	test -n "$DEBUG" && echo "$*" || true
}

echo "Starting server that will respond '${RESPONSE_CONTENT}' to every request"
RESPONSE_CONTENT="$RESPONSE_CONTENT" nc -lk -p 80 -e acme-server.sh &

SERVER_PID=$!
debug "waiting for request to process ${SERVER_PID}..."
wait $SERVER_PID
debug "done"
